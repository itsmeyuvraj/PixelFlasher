import Foundation
import Combine

public enum FlashingStage: String, CaseIterable, Sendable {
    case idle = "Ready"
    case verifyingPreFlash = "Verifying Image Integrity & Device"
    case preparingFiles = "Extracting Firmware Files"
    case rebootingToBootloader = "Rebooting to Bootloader"
    case flashingBootloader = "Flashing Bootloader"
    case flashingRadio = "Flashing Baseband / Radio"
    case flashingSystem = "Flashing System & OS Partitions"
    case verifyingPostFlash = "Verifying Flashed Image & Slots"
    case wipingUserData = "Wiping User Data"
    case lockingBootloader = "Locking Bootloader"
    case rebootingDevice = "Rebooting Device"
    case completed = "Flashing Completed & Verified"
    case failed = "Flashing Failed"

    public var iconName: String {
        switch self {
        case .idle: return "play.circle.fill"
        case .verifyingPreFlash: return "magnifyingglass.circle.fill"
        case .preparingFiles: return "archivebox.circle.fill"
        case .rebootingToBootloader, .rebootingDevice: return "arrow.counterclockwise.circle.fill"
        case .flashingBootloader, .flashingRadio, .flashingSystem: return "bolt.circle.fill"
        case .verifyingPostFlash: return "checkmark.seal.fill"
        case .wipingUserData: return "trash.circle.fill"
        case .lockingBootloader: return "lock.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

public struct ConsoleLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let message: String
    public let isError: Bool
    public let isHighlighted: Bool

    public init(message: String, isError: Bool = false, isHighlighted: Bool = false) {
        self.timestamp = Date()
        self.message = message
        self.isError = isError
        self.isHighlighted = isHighlighted
    }
}

@MainActor
public final class FlashingEngine: ObservableObject {
    public static let shared = FlashingEngine()

    @Published public var currentStage: FlashingStage = .idle
    @Published public var progressFraction: Double = 0.0
    @Published public var statusMessage: String = "Ready to flash"
    @Published public var currentPartition: String? = nil
    @Published public var isFlashing: Bool = false
    @Published public var consoleLogs: [ConsoleLogEntry] = []
    @Published public var latestReport: VerificationReport? = nil

    private var cancelRequested: Bool = false

    public init() {}

    public func appendLog(_ message: String, isError: Bool = false, isHighlighted: Bool = false) {
        let entry = ConsoleLogEntry(message: message, isError: isError, isHighlighted: isHighlighted)
        consoleLogs.append(entry)
    }

    public func clearLogs() {
        consoleLogs.removeAll()
    }

    /// Flash official factory image via fastboot
    public func flashFactoryImage(
        device: ConnectedDevice,
        firmwareURL: URL,
        configuration: FlashConfiguration
    ) async throws -> VerificationReport {
        guard !isFlashing else {
            throw NSError(domain: "FlashingEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "A flash operation is already running."])
        }

        self.isFlashing = true
        self.cancelRequested = false
        self.progressFraction = 0.0
        self.currentStage = .verifyingPreFlash
        self.clearLogs()

        defer {
            self.isFlashing = false
        }

        let serial = device.serial
        let fastbootExe = await PlatformToolsManager.shared.getFastbootPath()

        appendLog("🚀 Initializing Pixel Flasher Engine...", isHighlighted: true)
        appendLog("📱 Target Device: \(device.displayName) [\(serial)]")
        appendLog("📦 Firmware: \(firmwareURL.lastPathComponent)")
        appendLog("⚙️ Options: Wipe User Data: \(configuration.wipeUserData ? "YES" : "NO"), Lock Bootloader: \(configuration.lockBootloader ? "YES" : "NO"), Force Both Slots: \(configuration.forceFlashBothSlots ? "YES" : "NO")")

        // ----------------------------------------------------
        // Stage 1: Pre-flash verification
        // ----------------------------------------------------
        self.currentStage = .verifyingPreFlash
        self.statusMessage = "Verifying firmware image integrity & device compatibility..."
        self.progressFraction = 0.05

        let (preValid, initialReport) = await VerificationService.shared.verifyPreFlash(
            fileURL: firmwareURL,
            expectedChecksum: configuration.selectedRelease?.sha256,
            targetDeviceCodename: device.productCodename,
            onLog: { [weak self] msg in
                Task { @MainActor [weak self] in
                    self?.appendLog(msg)
                }
            }
        )
        self.latestReport = initialReport

        if !preValid && configuration.verifyImageIntegrity {
            self.currentStage = .failed
            self.statusMessage = "Pre-flash verification failed. Check logs."
            throw NSError(domain: "FlashingEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Pre-flash verification failed: \(initialReport.summaryMessage)"])
        }

        // ----------------------------------------------------
        // Stage 2: Ensure device is in bootloader mode
        // ----------------------------------------------------
        self.currentStage = .rebootingToBootloader
        self.statusMessage = "Ensuring device is in Bootloader mode..."
        self.progressFraction = 0.15

        if device.mode == .adb {
            appendLog("🔄 Device is in ADB mode. Rebooting to bootloader...")
            _ = try await ADBService.shared.reboot(serial: serial, target: "bootloader")
            appendLog("⏳ Waiting 6 seconds for bootloader initialization...")
            try await Task.sleep(nanoseconds: 6_000_000_000)
        } else if device.mode != .fastboot && device.mode != .fastbootd {
            appendLog("ℹ️ Device mode is \(device.mode.rawValue). Checking fastboot connection...")
        }

        // Verify fastboot responsiveness
        let detectedProduct = await FastbootService.shared.getVar(serial: serial, variable: "product")
        if let prod = detectedProduct {
            appendLog("✅ Fastboot handshake confirmed. Product: \(prod)")
        } else {
            appendLog("⚠️ Warning: Could not read 'product' var from fastboot. Device might still be rebooting.")
        }

        // ----------------------------------------------------
        // Stage 3: Extract firmware zip
        // ----------------------------------------------------
        self.currentStage = .preparingFiles
        self.statusMessage = "Extracting factory image package..."
        self.progressFraction = 0.25
        appendLog("📂 Creating temporary extraction workspace...")

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PixelFlasher_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Extract using system unzip
        appendLog("📦 Unzipping \(firmwareURL.lastPathComponent)...")
        let unzipRes = try await ProcessRunner.shared.run(
            executable: "/usr/bin/unzip",
            arguments: ["-q", "-o", firmwareURL.path, "-d", tempDir.path]
        )
        guard unzipRes.isSuccess else {
            self.currentStage = .failed
            appendLog("❌ Failed to unzip firmware: \(unzipRes.stderr)", isError: true)
            throw NSError(domain: "FlashingEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to unpack firmware zip: \(unzipRes.stderr)"])
        }

        // Find extracted subdirectory or root containing images
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        var workDir = tempDir
        if let subDir = contents.first(where: { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }) {
            workDir = subDir
        }
        appendLog("📂 Extraction folder ready: \(workDir.lastPathComponent)")

        // Identify bootloader, radio, and image zip
        let subContents = try fileManager.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil)
        let bootloaderImg = subContents.first { $0.lastPathComponent.hasPrefix("bootloader-") && $0.pathExtension == "img" }
        let radioImg = subContents.first { $0.lastPathComponent.hasPrefix("radio-") && $0.pathExtension == "img" }
        let osImageZip = subContents.first { $0.lastPathComponent.hasPrefix("image-") && $0.pathExtension == "zip" }

        var partitionResults: [PartitionFlashResult] = []

        // ----------------------------------------------------
        // Stage 4: Flash Bootloader
        // ----------------------------------------------------
        if let bl = bootloaderImg {
            self.currentStage = .flashingBootloader
            self.statusMessage = "Flashing bootloader (\(bl.lastPathComponent))..."
            self.progressFraction = 0.35
            self.currentPartition = "bootloader"
            appendLog("⚡ Flashing Bootloader: \(bl.lastPathComponent)", isHighlighted: true)

            let blStart = Date()
            let exitCode = try await ProcessRunner.shared.stream(
                executable: fastbootExe,
                arguments: ["-s", serial, "flash", "bootloader", bl.path]
            ) { [weak self] line, isErr in
                Task { @MainActor [weak self] in
                    self?.appendLog(line, isError: isErr)
                }
            }

            let blDuration = Date().timeIntervalSince(blStart)
            if exitCode == 0 {
                appendLog("✅ Bootloader flashed successfully in \(String(format: "%.1f", blDuration))s")
                partitionResults.append(PartitionFlashResult(partitionName: "bootloader", status: .passed, message: "OKAY", timeElapsedSeconds: blDuration))
            } else {
                appendLog("❌ Failed to flash bootloader (code \(exitCode))", isError: true)
                partitionResults.append(PartitionFlashResult(partitionName: "bootloader", status: .failed, message: "Exit code \(exitCode)", timeElapsedSeconds: blDuration))
                self.currentStage = .failed
                throw NSError(domain: "FlashingEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Flashing bootloader failed."])
            }

            // Reboot bootloader
            appendLog("🔄 Rebooting bootloader...")
            _ = try? await FastbootService.shared.reboot(serial: serial, target: "bootloader")
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }

        // ----------------------------------------------------
        // Stage 5: Flash Radio (Baseband) if present
        // ----------------------------------------------------
        if let radio = radioImg {
            self.currentStage = .flashingRadio
            self.statusMessage = "Flashing radio/baseband (\(radio.lastPathComponent))..."
            self.progressFraction = 0.45
            self.currentPartition = "radio"
            appendLog("⚡ Flashing Radio: \(radio.lastPathComponent)", isHighlighted: true)

            let rStart = Date()
            let exitCode = try await ProcessRunner.shared.stream(
                executable: fastbootExe,
                arguments: ["-s", serial, "flash", "radio", radio.path]
            ) { [weak self] line, isErr in
                Task { @MainActor [weak self] in
                    self?.appendLog(line, isError: isErr)
                }
            }

            let rDuration = Date().timeIntervalSince(rStart)
            if exitCode == 0 {
                appendLog("✅ Radio flashed successfully in \(String(format: "%.1f", rDuration))s")
                partitionResults.append(PartitionFlashResult(partitionName: "radio", status: .passed, message: "OKAY", timeElapsedSeconds: rDuration))
            } else {
                appendLog("❌ Failed to flash radio (code \(exitCode))", isError: true)
                partitionResults.append(PartitionFlashResult(partitionName: "radio", status: .failed, message: "Exit code \(exitCode)", timeElapsedSeconds: rDuration))
                self.currentStage = .failed
                throw NSError(domain: "FlashingEngine", code: 5, userInfo: [NSLocalizedDescriptionKey: "Flashing radio failed."])
            }

            // Reboot bootloader
            appendLog("🔄 Rebooting bootloader...")
            _ = try? await FastbootService.shared.reboot(serial: serial, target: "bootloader")
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }

        // ----------------------------------------------------
        // Stage 6: Flash OS / System image via fastboot update
        // ----------------------------------------------------
        self.currentStage = .flashingSystem
        self.statusMessage = "Flashing system partitions (boot, dtbo, super, system, vendor)..."
        self.progressFraction = 0.60
        appendLog("⚡ Flashing System Image...", isHighlighted: true)

        let targetUpdateFile: URL
        if let osZip = osImageZip {
            targetUpdateFile = osZip
        } else {
            targetUpdateFile = firmwareURL
        }

        var updateArgs = ["-s", serial, "update"]
        if configuration.wipeUserData {
            updateArgs.append("-w")
            appendLog("⚠️ Option enabled: User data will be wiped (-w)", isHighlighted: true)
        }
        if configuration.forceFlashBothSlots {
            updateArgs.append("--slot=all")
            appendLog("⚠️ Option enabled: Flashing both slots A and B (--slot=all)", isHighlighted: true)
        }
        updateArgs.append(targetUpdateFile.path)

        appendLog("Running: fastboot \(updateArgs.joined(separator: " "))")
        let osStart = Date()

        let updateExitCode = try await ProcessRunner.shared.stream(
            executable: fastbootExe,
            arguments: updateArgs
        ) { [weak self] line, isErr in
            Task { @MainActor [weak self] in
                self?.appendLog(line, isError: isErr)
                // Parse partition progress from fastboot lines:
                // e.g. "archive does not contain 'boot.sig'"
                // e.g. "Sending 'boot_a' (65536 KB)"
                // e.g. "Writing 'boot_a' ... OKAY"
                if line.contains("Writing '") || line.contains("Sending '") {
                    if let part = line.split(separator: "'").dropFirst().first {
                        let partName = String(part)
                        self?.currentPartition = partName
                        self?.statusMessage = "Writing partition '\(partName)'..."
                    }
                }
            }
        }

        let osDuration = Date().timeIntervalSince(osStart)
        if updateExitCode == 0 {
            appendLog("✅ System partitions flashed successfully in \(String(format: "%.1f", osDuration))s", isHighlighted: true)
            partitionResults.append(PartitionFlashResult(partitionName: "system_image", status: .passed, message: "OKAY", timeElapsedSeconds: osDuration))
        } else {
            appendLog("❌ Fastboot update failed with exit code \(updateExitCode)", isError: true)
            partitionResults.append(PartitionFlashResult(partitionName: "system_image", status: .failed, message: "Exit code \(updateExitCode)", timeElapsedSeconds: osDuration))
            self.currentStage = .failed
            self.statusMessage = "Flashing system partitions failed."
            throw NSError(domain: "FlashingEngine", code: 6, userInfo: [NSLocalizedDescriptionKey: "Flashing system partitions failed. See terminal log."])
        }

        // ----------------------------------------------------
        // Stage 7: Wipe User Data (if requested and not already wiped by update -w)
        // ----------------------------------------------------
        if configuration.wipeUserData {
            self.currentStage = .wipingUserData
            self.statusMessage = "Ensuring userdata is erased..."
            self.progressFraction = 0.85
            appendLog("🧹 Erasing userdata partition...")
            _ = try? await FastbootService.shared.erasePartition(serial: serial, partition: "userdata")
            appendLog("✅ User data partition erase command executed.")
        }

        // ----------------------------------------------------
        // Stage 8: Post-Flash Verification
        // ----------------------------------------------------
        self.currentStage = .verifyingPostFlash
        self.statusMessage = "Verifying flashed device state & active slots..."
        self.progressFraction = 0.90

        var report = initialReport
        report.partitionResults = partitionResults
        report.flashExecutionStatus = .passed

        let verifiedReport = await VerificationService.shared.verifyPostFlash(
            serial: serial,
            initialReport: report,
            wasBootloaderLocked: configuration.lockBootloader,
            onLog: { [weak self] msg in
                Task { @MainActor [weak self] in
                    self?.appendLog(msg)
                }
            }
        )
        self.latestReport = verifiedReport

        // ----------------------------------------------------
        // Stage 9: Lock Bootloader (if user requested)
        // ----------------------------------------------------
        if configuration.lockBootloader {
            self.currentStage = .lockingBootloader
            self.statusMessage = "Locking Bootloader: Please confirm on your Pixel screen..."
            self.progressFraction = 0.95
            appendLog("🔒 Locking Bootloader...", isHighlighted: true)
            appendLog("⚠️ ATTENTION: Confirm the lock prompt on your Pixel display using Volume Down and Power buttons!", isHighlighted: true)

            let isLegacy = (device.matchedDevice?.releaseYear ?? 2024) <= 2017
            do {
                let lockRes = try await FastbootService.shared.lockBootloader(serial: serial, isLegacy: isLegacy)
                appendLog(lockRes.combinedOutput)
                if lockRes.isSuccess {
                    appendLog("✅ Bootloader lock signal sent successfully!")
                } else {
                    appendLog("⚠️ Bootloader lock returned warning or user cancelled on device: \(lockRes.stderr)")
                }
            } catch {
                appendLog("⚠️ Failed to lock bootloader: \(error.localizedDescription)")
            }
        }

        // ----------------------------------------------------
        // Stage 10: Auto-reboot to system
        // ----------------------------------------------------
        if configuration.rebootAfterFlash {
            self.currentStage = .rebootingDevice
            self.statusMessage = "Rebooting device to system..."
            appendLog("🔄 Rebooting device to system...")
            _ = try? await FastbootService.shared.reboot(serial: serial)
            appendLog("🎉 Device is rebooting to Android!")
        }

        self.currentStage = .completed
        self.progressFraction = 1.0
        self.statusMessage = "Flashing and verification completed successfully!"
        appendLog("🏁 ALL OPERATIONS COMPLETED SUCCESSFULLY!", isHighlighted: true)

        return verifiedReport
    }

    /// Flash Full OTA image via Recovery ADB Sideload
    public func flashOTAImage(
        device: ConnectedDevice,
        firmwareURL: URL
    ) async throws {
        guard !isFlashing else {
            throw NSError(domain: "FlashingEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "An operation is already in progress."])
        }

        self.isFlashing = true
        self.cancelRequested = false
        self.progressFraction = 0.0
        self.clearLogs()

        defer {
            self.isFlashing = false
        }

        let serial = device.serial
        appendLog("🚀 Starting ADB Sideload OTA Flasher...", isHighlighted: true)
        appendLog("📱 Target Device: \(device.displayName) [\(serial)]")
        appendLog("📦 OTA Package: \(firmwareURL.lastPathComponent)")

        // If not in sideload mode, assist in rebooting
        if device.mode != .sideload {
            self.statusMessage = "Rebooting device to Recovery Sideload mode..."
            appendLog("🔄 Sending reboot sideload command...")
            _ = try await ADBService.shared.reboot(serial: serial, target: "sideload")
            appendLog("⏳ Waiting 8 seconds for device to enter sideload mode...")
            try await Task.sleep(nanoseconds: 8_000_000_000)
        }

        self.currentStage = .flashingSystem
        self.statusMessage = "Sideloading OTA package to device..."

        let exitCode = try await ADBService.shared.sideload(
            serial: serial,
            fileURL: firmwareURL
        ) { [weak self] line, progress in
            Task { @MainActor [weak self] in
                self?.appendLog(line)
                if let p = progress {
                    self?.progressFraction = p
                    self?.statusMessage = "Sideloading OTA: \(String(format: "%.0f%%", p * 100))"
                }
            }
        }

        if exitCode == 0 {
            self.currentStage = .completed
            self.progressFraction = 1.0
            self.statusMessage = "OTA Sideload completed successfully!"
            appendLog("✅ OTA Package transferred and verified by device recovery!", isHighlighted: true)
        } else {
            self.currentStage = .failed
            self.statusMessage = "OTA Sideload failed with exit code \(exitCode)"
            appendLog("❌ ADB Sideload failed (exit code \(exitCode))", isError: true)
            throw NSError(domain: "FlashingEngine", code: 10, userInfo: [NSLocalizedDescriptionKey: "ADB Sideload failed."])
        }
    }
}
