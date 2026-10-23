import SwiftUI

public struct DeviceHeaderView: View {
    @ObservedObject var monitor = DeviceMonitor.shared
    @State private var isPerformingReboot = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if let device = monitor.selectedDevice {
                connectedDeviceCard(device)
            } else {
                noDeviceCard
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Device Action"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private func connectedDeviceCard(_ device: ConnectedDevice) -> some View {
        HStack(spacing: 16) {
            // Device icon & glow
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: "iphone.gen3")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(device.displayName)
                        .font(.headline)
                        .fontWeight(.bold)

                    // Mode Badge
                    Text(device.mode.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(modeColor(device.mode).opacity(0.2))
                        .foregroundColor(modeColor(device.mode))
                        .clipShape(Capsule())

                    // Bootloader Lock Badge
                    if device.bootloaderState != .unknown {
                        Text(device.bootloaderState == .unlocked ? "🔓 Bootloader Unlocked" : "🔒 Bootloader Locked")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(device.bootloaderState == .unlocked ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(device.bootloaderState == .unlocked ? .orange : .green)
                            .clipShape(Capsule())
                    }

                    // Slot Badge
                    if let slot = device.currentSlot {
                        Text("Slot: \(slot.uppercased())")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                HStack(spacing: 12) {
                    Label("Serial: \(device.serial)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let codename = device.productCodename {
                        Label("Codename: \(codename)", systemImage: "cpu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let soc = device.matchedDevice?.soc {
                        Label(soc, systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Quick Reboot Actions
            HStack(spacing: 8) {
                Menu {
                    Button(action: { rebootDevice(to: "bootloader") }) {
                        Label("Reboot to Bootloader", systemImage: "wrench.and.screwdriver")
                    }
                    Button(action: { rebootDevice(to: "recovery") }) {
                        Label("Reboot to Recovery", systemImage: "cross.case")
                    }
                    Button(action: { rebootDevice(to: "sideload") }) {
                        Label("Reboot to ADB Sideload", systemImage: "arrow.down.to.line.compact")
                    }
                    Divider()
                    Button(action: { rebootDevice(to: nil) }) {
                        Label("Reboot to System", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Label("Reboot", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isPerformingReboot)

                Button(action: {
                    Task {
                        await monitor.scanDevices()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Connected Devices")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var noDeviceCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "cable.connector.slash")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("No Pixel Device Connected")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Plug in your Pixel with USB Debugging enabled, or boot into Fastboot (Power + Vol Down).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task {
                    await monitor.scanDevices()
                }
            }) {
                HStack(spacing: 6) {
                    if monitor.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Scan Devices")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func modeColor(_ mode: DeviceMode) -> Color {
        switch mode {
        case .adb: return .blue
        case .fastboot: return .green
        case .fastbootd: return .purple
        case .sideload: return .orange
        case .recovery: return .yellow
        case .unauthorized: return .red
        case .offline, .unknown: return .gray
        }
    }

    private func rebootDevice(to target: String?) {
        guard let dev = monitor.selectedDevice else { return }
        isPerformingReboot = true

        Task {
            do {
                if dev.mode == .adb {
                    _ = try await ADBService.shared.reboot(serial: dev.serial, target: target)
                } else {
                    _ = try await FastbootService.shared.reboot(serial: dev.serial, target: target)
                }
                alertMessage = "Reboot command sent to \(dev.displayName)."
                showAlert = true
            } catch {
                alertMessage = "Reboot failed: \(error.localizedDescription)"
                showAlert = true
            }
            isPerformingReboot = false
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await monitor.scanDevices()
        }
    }
}
