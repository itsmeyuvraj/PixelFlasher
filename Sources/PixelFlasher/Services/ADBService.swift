import Foundation

public actor ADBService {
    public static let shared = ADBService()

    public init() {}

    private func adbExecutable() async -> String {
        return await PlatformToolsManager.shared.getAdbPath()
    }

    /// List connected devices via ADB
    public func listDevices() async -> [ConnectedDevice] {
        let exe = await adbExecutable()
        do {
            let res = try await ProcessRunner.shared.run(executable: exe, arguments: ["devices", "-l"])
            var devices: [ConnectedDevice] = []
            let lines = res.stdout.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("List of devices") else { continue }
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 2 else { continue }

                let serial = parts[0]
                let stateStr = parts[1]

                var mode: DeviceMode = .adb
                switch stateStr {
                case "device": mode = .adb
                case "recovery": mode = .recovery
                case "sideload": mode = .sideload
                case "unauthorized": mode = .unauthorized
                case "offline": mode = .offline
                default: mode = .unknown
                }

                var productCodename: String? = nil
                var buildId: String? = nil

                // Check -l details (e.g. product:husky model:Pixel_8_Pro device:husky)
                for part in parts {
                    if part.hasPrefix("product:") {
                        productCodename = String(part.dropFirst("product:".count))
                    } else if part.hasPrefix("device:") && productCodename == nil {
                        productCodename = String(part.dropFirst("device:".count))
                    }
                }

                // If authorized, get properties
                if mode == .adb {
                    if let propDevice = await getProp(serial: serial, property: "ro.product.device") {
                        productCodename = propDevice
                    }
                    buildId = await getProp(serial: serial, property: "ro.build.display.id")
                }

                let dev = ConnectedDevice(
                    serial: serial,
                    mode: mode,
                    productCodename: productCodename,
                    bootloaderState: .unknown,
                    currentSlot: nil,
                    buildId: buildId
                )
                devices.append(dev)
            }
            return devices
        } catch {
            return []
        }
    }

    /// Get system property via adb shell getprop
    public func getProp(serial: String, property: String) async -> String? {
        let exe = await adbExecutable()
        do {
            let res = try await ProcessRunner.shared.run(executable: exe, arguments: ["-s", serial, "shell", "getprop", property])
            let val = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return val.isEmpty ? nil : val
        } catch {
            return nil
        }
    }

    /// Reboot device to bootloader, recovery, sideload, or system
    public func reboot(serial: String, target: String? = nil) async throws -> ProcessResult {
        let exe = await adbExecutable()
        var args = ["-s", serial, "reboot"]
        if let target = target {
            args.append(target)
        }
        return try await ProcessRunner.shared.run(executable: exe, arguments: args)
    }

    /// Flash OTA via ADB Sideload with progress streaming
    public func sideload(
        serial: String,
        fileURL: URL,
        onOutput: @escaping @Sendable (String, Double?) -> Void
    ) async throws -> Int32 {
        let exe = await adbExecutable()
        return try await ProcessRunner.shared.stream(
            executable: exe,
            arguments: ["-s", serial, "sideload", fileURL.path]
        ) { line, _ in
            // Parse adb sideload output:
            // e.g. "serving: 'husky-ota.zip'  (~45%)"
            var progress: Double? = nil
            if line.contains("%") {
                let scanner = Scanner(string: line)
                if scanner.scanUpToString("%") != nil {
                    // Try to extract percentage
                    let digits = line.filter { "0123456789.".contains($0) }
                    if let pct = Double(digits) {
                        progress = min(max(pct / 100.0, 0.0), 1.0)
                    }
                }
            }
            onOutput(line, progress)
        }
    }

    /// Restart ADB server
    public func restartServer() async throws {
        let exe = await adbExecutable()
        _ = try? await ProcessRunner.shared.run(executable: exe, arguments: ["kill-server"])
        _ = try? await ProcessRunner.shared.run(executable: exe, arguments: ["start-server"])
    }
}
