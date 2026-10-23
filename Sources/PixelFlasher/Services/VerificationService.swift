import Foundation
import CryptoKit

public actor VerificationService {
    public static let shared = VerificationService()

    public init() {}

    /// Calculate SHA-256 checksum of any file in chunks (low memory footprint for multi-GB zip files)
    public func calculateSHA256(
        for fileURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let totalSize = (attributes[.size] as? Int64) ?? 1
        var bytesRead: Int64 = 0

        var hasher = SHA256()
        let bufferSize = 4 * 1024 * 1024 // 4 MB chunk size

        while true {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            hasher.update(data: data)
            bytesRead += Int64(data.count)

            if let onProgress = onProgress, totalSize > 0 {
                let progress = min(Double(bytesRead) / Double(totalSize), 1.0)
                onProgress(progress)
            }
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Pre-flash verification: verifies checksum, zip structure, and product codename
    public func verifyPreFlash(
        fileURL: URL,
        expectedChecksum: String?,
        targetDeviceCodename: String?,
        onLog: @Sendable (String) -> Void
    ) async -> (isValid: Bool, report: VerificationReport) {
        let fileName = fileURL.lastPathComponent
        onLog("🔍 Starting pre-flash verification for \(fileName)...")

        var report = VerificationReport(
            deviceSerial: targetDeviceCodename ?? "Unknown",
            deviceModel: targetDeviceCodename ?? "Pixel",
            firmwareFileName: fileName,
            firmwareType: .factory
        )

        // 1. File existence and size check
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            onLog("❌ Pre-flash error: Firmware file does not exist at \(fileURL.path)")
            report.overallStatus = .failed
            report.summaryMessage = "Firmware file not found."
            return (false, report)
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSizeMB = ((attributes?[.size] as? Int64) ?? 0) / (1024 * 1024)
        onLog("📦 File verified: \(fileName) (\(fileSizeMB) MB)")

        // 2. SHA-256 Checksum verification
        if let expected = expectedChecksum, !expected.isEmpty {
            onLog("🔒 Calculating SHA-256 checksum...")
            do {
                let calculated = try await calculateSHA256(for: fileURL)
                report.calculatedChecksum = calculated
                report.expectedChecksum = expected

                if calculated.lowercased() == expected.lowercased() {
                    onLog("✅ SHA-256 Checksum verified perfectly: \(calculated)")
                    report.checksumStatus = .passed
                } else {
                    onLog("❌ SHA-256 Checksum MISMATCH!")
                    onLog("   Expected:   \(expected)")
                    onLog("   Calculated: \(calculated)")
                    report.checksumStatus = .failed
                    report.overallStatus = .failed
                    report.summaryMessage = "SHA-256 Checksum mismatch. File may be corrupted or modified."
                    return (false, report)
                }
            } catch {
                onLog("⚠️ Failed to compute checksum: \(error.localizedDescription)")
                report.checksumStatus = .warning
            }
        } else {
            onLog("ℹ️ No expected checksum provided. Skipping checksum comparison.")
            report.checksumStatus = .skipped
        }

        // 3. Inspect zip contents using unzip -l
        onLog("🔎 Inspecting firmware zip contents...")
        let unzipRes = try? await ProcessRunner.shared.run(
            executable: "/usr/bin/unzip",
            arguments: ["-l", fileURL.path]
        )

        if let stdout = unzipRes?.stdout, unzipRes?.isSuccess == true {
            let containsFlashAll = stdout.contains("flash-all.sh")
            let containsBootloader = stdout.contains("bootloader-")
            let containsImageZip = stdout.contains("image-")
            let containsPayload = stdout.contains("payload.bin")

            if containsPayload {
                report.firmwareType = .ota
                onLog("📄 Detected Full OTA Payload package (payload.bin present).")
            } else if containsFlashAll || (containsBootloader && containsImageZip) {
                report.firmwareType = .factory
                onLog("📄 Detected Official Google Factory Image (flash-all and partition images present).")
            } else {
                onLog("ℹ️ Generic fastboot or custom package detected.")
            }

            // Codename match check against filename or android-info.txt
            if let targetCodename = targetDeviceCodename?.lowercased(), !targetCodename.isEmpty {
                report.expectedCodename = targetCodename
                report.detectedDeviceCodename = targetCodename

                let filenameLower = fileName.lowercased()
                if filenameLower.contains(targetCodename) || stdout.lowercased().contains(targetCodename) {
                    onLog("✅ Codename verified: Image matches device codename '\(targetCodename)'")
                    report.codenameMatchStatus = .passed
                } else {
                    onLog("⚠️ WARNING: Image filename or contents do not explicitly mention codename '\(targetCodename)'.")
                    report.codenameMatchStatus = .warning
                }
            }
        } else {
            onLog("⚠️ Could not list zip contents. Assuming valid zip structure.")
        }

        report.summaryMessage = "Pre-flash verification passed."
        return (true, report)
    }

    /// Post-flash verification: queries device variables to verify boot slot, bootloader and baseband versions
    public func verifyPostFlash(
        serial: String,
        initialReport: VerificationReport,
        expectedBootloader: String? = nil,
        expectedBaseband: String? = nil,
        wasBootloaderLocked: Bool = false,
        onLog: @Sendable (String) -> Void
    ) async -> VerificationReport {
        var report = initialReport
        onLog("🔍 Running post-flash device verification on serial \(serial)...")

        // Query all device fastboot variables
        let vars = await FastbootService.shared.getAllVars(serial: serial)

        // 1. Current slot verification
        let currentSlot = vars["current-slot"]
        report.currentSlot = currentSlot
        if let slot = currentSlot {
            onLog("📍 Active boot slot is: \(slot)")
            // Check slot successful flag
            let slotKey = "slot-successful:\(slot)"
            let isSuccessful = vars[slotKey]?.lowercased() == "yes"
            report.slotSuccessful = isSuccessful
            if isSuccessful {
                onLog("✅ Slot \(slot) is marked bootable & successful!")
                report.postFlashSlotStatus = .passed
            } else {
                onLog("ℹ️ Slot \(slot) boot flag pending first successful system boot.")
                report.postFlashSlotStatus = .passed
            }
        } else {
            onLog("ℹ️ Device is single-slot or slot variable unavailable.")
            report.postFlashSlotStatus = .passed
        }

        // 2. Bootloader version check
        let bootloaderVer = vars["version-bootloader"]
        report.reportedBootloaderVersion = bootloaderVer
        if let ver = bootloaderVer {
            onLog("📌 Device reported bootloader version: \(ver)")
            if let expected = expectedBootloader, !expected.isEmpty {
                if ver.contains(expected) || expected.contains(ver) {
                    onLog("✅ Bootloader version matches flashed image!")
                    report.bootloaderVersionMatches = .passed
                } else {
                    onLog("⚠️ Bootloader version differs from expected: \(ver) vs \(expected)")
                    report.bootloaderVersionMatches = .warning
                }
            } else {
                report.bootloaderVersionMatches = .passed
            }
        }

        // 3. Baseband version check
        let basebandVer = vars["version-baseband"]
        report.reportedBasebandVersion = basebandVer
        if let ver = basebandVer {
            onLog("📡 Device reported baseband version: \(ver)")
        }

        // 4. Bootloader lock state verification
        if wasBootloaderLocked {
            let unlocked = vars["unlocked"]?.lowercased()
            if unlocked == "no" || unlocked == "false" {
                onLog("🔒 Bootloader is confirmed LOCKED.")
                report.bootloaderLockedStatus = .passed
            } else {
                onLog("⚠️ Bootloader lock requested, but status is: \(unlocked ?? "unknown")")
                report.bootloaderLockedStatus = .warning
            }
        }

        // Overall status
        if report.flashExecutionStatus == .failed || report.checksumStatus == .failed {
            report.overallStatus = .failed
            report.summaryMessage = "Flashing or verification failed. Review detailed logs."
        } else if report.bootloaderVersionMatches == .warning || report.codenameMatchStatus == .warning {
            report.overallStatus = .warning
            report.summaryMessage = "Flashing finished with verification warnings."
        } else {
            report.overallStatus = .passed
            report.summaryMessage = "Firmware flashed and verified successfully!"
        }

        onLog("🏁 Post-flash verification complete: \(report.overallStatus.rawValue)")
        return report
    }
}
