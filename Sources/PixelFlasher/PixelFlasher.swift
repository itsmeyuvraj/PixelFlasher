import SwiftUI
import AppKit

@main
struct PixelFlasherApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        Task {
            _ = await PlatformToolsManager.shared.detectTools()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Device") {
                Button("Scan Connected Devices") {
                    Task {
                        await DeviceMonitor.shared.scanDevices()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("Reboot to Bootloader") {
                    if let dev = DeviceMonitor.shared.selectedDevice {
                        Task {
                            if dev.mode == .adb {
                                _ = try? await ADBService.shared.reboot(serial: dev.serial, target: "bootloader")
                            } else {
                                _ = try? await FastbootService.shared.reboot(serial: dev.serial, target: "bootloader")
                            }
                        }
                    }
                }
                Button("Reboot to Recovery") {
                    if let dev = DeviceMonitor.shared.selectedDevice {
                        Task {
                            if dev.mode == .adb {
                                _ = try? await ADBService.shared.reboot(serial: dev.serial, target: "recovery")
                            } else {
                                _ = try? await FastbootService.shared.reboot(serial: dev.serial, target: "recovery")
                            }
                        }
                    }
                }
            }
        }
    }
}
