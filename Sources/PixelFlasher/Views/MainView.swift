import SwiftUI

public enum NavigationItem: String, CaseIterable, Identifiable {
    case flasher = "Flash Firmware"
    case browser = "Firmware Browser"
    case sideload = "OTA Sideload"
    case verification = "Verification Hub"
    case toolbox = "Fastboot Toolbox"
    case settings = "Settings"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .flasher: return "bolt.fill"
        case .browser: return "globe"
        case .sideload: return "arrow.down.to.line.compact"
        case .verification: return "checkmark.seal.fill"
        case .toolbox: return "wrench.and.screwdriver.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainView: View {
    @ObservedObject var monitor = DeviceMonitor.shared
    @State private var selectedTab: NavigationItem? = .flasher

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 960, minHeight: 650)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                deviceStatusToolbarItem
            }
        }
    }

    private var sidebarContent: some View {
        List(NavigationItem.allCases, selection: $selectedTab) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
                    .font(.system(.body, design: .rounded))
                    .padding(.vertical, 3)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Pixel Flasher")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .flasher:
            FlashWizardView()
                .navigationTitle("Flash Official Firmware")
        case .browser:
            FirmwareBrowserView()
                .navigationTitle("Firmware & Beta Catalog")
        case .sideload:
            OTASideloadView()
                .navigationTitle("OTA Recovery Sideload")
        case .verification:
            VerificationHubView()
                .navigationTitle("Flash & Checksum Verification")
        case .toolbox:
            FastbootToolboxView()
                .navigationTitle("Fastboot Toolbox")
        case .settings:
            SettingsView()
                .navigationTitle("Settings")
        case .none:
            Text("Select an item from the sidebar")
                .foregroundColor(.secondary)
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.selectedDevice != nil ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(monitor.selectedDevice?.displayName ?? "No Device")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Text("v1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var deviceStatusToolbarItem: some View {
        HStack(spacing: 8) {
            if let dev = monitor.selectedDevice {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(dev.displayName) (\(dev.mode.rawValue))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("No Device Connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
