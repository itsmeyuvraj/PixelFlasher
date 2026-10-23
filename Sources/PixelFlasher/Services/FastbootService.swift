import Foundation

public actor FastbootService {
    public static let shared = FastbootService()

    public init() {}

    private func fastbootExecutable() async -> String {
        return await PlatformToolsManager.shared.getFastbootPath()
    }

    /// List connected devices in fastboot/bootloader mode
    public func listDevices() async -> [ConnectedDevice] {
        let exe = await fastbootExecutable()
        do {
            let res = try await ProcessRunner.shared.run(executable: exe, arguments: ["devices", "-l"])
            var devices: [ConnectedDevice] = []
            let lines = res.stdout.components(separatedBy: .newlines)
            for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard let serial = parts.first else { continue }

                // Check mode
                var mode: DeviceMode = .fastboot
                if line.contains("fastbootd") {
                    mode = .fastbootd
                }

                // Query details for this device
                let codename = await getVar(serial: serial, variable: "product")
                let unlockedStr = await getVar(serial: serial, variable: "unlocked")
                let currentSlot = await getVar(serial: serial, variable: "current-slot")
                let bootloaderVer = await getVar(serial: serial, variable: "version-bootloader")
                let basebandVer = await getVar(serial: serial, variable: "version-baseband")
                var batteryLevel = await getVar(serial: serial, variable: "battery-soc-ok")
                if batteryLevel == nil {
                    batteryLevel = await getVar(serial: serial, variable: "battery-voltage")
                }

                let lockState: BootloaderLockState
                if let unlocked = unlockedStr?.lowercased() {
                    if unlocked.contains("yes") || unlocked.contains("true") {
                        lockState = .unlocked
                    } else if unlocked.contains("no") || unlocked.contains("false") {
                        lockState = .locked
                    } else {
                        lockState = .unknown
                    }
                } else {
                    lockState = .unknown
                }

                let dev = ConnectedDevice(
                    serial: serial,
                    mode: mode,
                    productCodename: codename,
                    bootloaderState: lockState,
                    currentSlot: currentSlot,
                    bootloaderVersion: bootloaderVer,
                    basebandVersion: basebandVer,
                    batteryLevel: batteryLevel
                )
                devices.append(dev)
            }
            return devices
        } catch {
            return []
        }
    }

    /// Get a single fastboot variable value
    public func getVar(serial: String, variable: String) async -> String? {
        let exe = await fastbootExecutable()
        do {
            let res = try await ProcessRunner.shared.run(executable: exe, arguments: ["-s", serial, "getvar", variable])
            // Fastboot outputs getvar info to stderr: e.g. "product: husky\nFinished. Total time: ..."
            let combined = res.combinedOutput
            for line in combined.components(separatedBy: .newlines) {
                if line.hasPrefix("\(variable):") {
                    let val = line.dropFirst("\(variable):".count).trimmingCharacters(in: .whitespaces)
                    return val.isEmpty ? nil : val
                }
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Get all fastboot variables
    public func getAllVars(serial: String) async -> [String: String] {
        let exe = await fastbootExecutable()
        do {
            let res = try await ProcessRunner.shared.run(executable: exe, arguments: ["-s", serial, "getvar", "all"])
            var dict: [String: String] = [:]
            let combined = res.combinedOutput
            for line in combined.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.contains(":") else { continue }
                // Remove "(bootloader) " prefix if present
                var clean = trimmed
                if clean.hasPrefix("(bootloader)") {
                    clean = clean.replacingOccurrences(of: "(bootloader)", with: "").trimmingCharacters(in: .whitespaces)
                }
                let parts = clean.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let k = parts[0].trimmingCharacters(in: .whitespaces)
                    let v = parts[1].trimmingCharacters(in: .whitespaces)
                    if !k.isEmpty && k != "Finished." {
                        dict[k] = v
                    }
                }
            }
            return dict
        } catch {
            return [:]
        }
    }

    /// Reboot device
    public func reboot(serial: String, target: String? = nil) async throws -> ProcessResult {
        let exe = await fastbootExecutable()
        var args = ["-s", serial, "reboot"]
        if let target = target {
            if target == "bootloader" {
                args = ["-s", serial, "reboot-bootloader"]
            } else {
                args.append(target)
            }
        }
        return try await ProcessRunner.shared.run(executable: exe, arguments: args)
    }

    /// Set active boot slot
    public func setActiveSlot(serial: String, slot: String) async throws -> ProcessResult {
        let exe = await fastbootExecutable()
        let cleanSlot = slot.replacingOccurrences(of: "_", with: "")
        return try await ProcessRunner.shared.run(executable: exe, arguments: ["-s", serial, "--set-active=\(cleanSlot)"])
    }

    /// Lock bootloader (fastboot flashing lock / fastboot oem lock)
    public func lockBootloader(serial: String, isLegacy: Bool = false) async throws -> ProcessResult {
        let exe = await fastbootExecutable()
        let args = isLegacy ? ["-s", serial, "oem", "lock"] : ["-s", serial, "flashing", "lock"]
        return try await ProcessRunner.shared.run(executable: exe, arguments: args)
    }

    /// Unlock bootloader (fastboot flashing unlock / fastboot oem unlock)
    public func unlockBootloader(serial: String, isLegacy: Bool = false) async throws -> ProcessResult {
        let exe = await fastbootExecutable()
        let args = isLegacy ? ["-s", serial, "oem", "unlock"] : ["-s", serial, "flashing", "unlock"]
        return try await ProcessRunner.shared.run(executable: exe, arguments: args)
    }

    /// Erase a specific partition (e.g. userdata)
    public func erasePartition(serial: String, partition: String) async throws -> ProcessResult {
        let exe = await fastbootExecutable()
        return try await ProcessRunner.shared.run(executable: exe, arguments: ["-s", serial, "erase", partition])
    }
}
