import SwiftUI

public struct FastbootToolboxView: View {
    @ObservedObject var monitor = DeviceMonitor.shared

    @State private var deviceVariables: [String: String] = [:]
    @State private var isLoadingVars = false
    @State private var searchVarQuery = ""
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showLockConfirm = false
    @State private var showUnlockConfirm = false
    @State private var showEraseConfirm = false

    public init() {}

    private var filteredVariables: [(key: String, value: String)] {
        let sorted = deviceVariables.sorted { $0.key < $1.key }
        if searchVarQuery.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.key.localizedCaseInsensitiveContains(searchVarQuery) ||
            $0.value.localizedCaseInsensitiveContains(searchVarQuery)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DeviceHeaderView()

                // Diagnostic Quick Actions
                quickActionsSection

                // Bootloader Lock / Unlock
                bootloaderSecuritySection

                // Slot Switcher & Partition Tools
                slotAndPartitionSection

                // Variables Inspector
                fastbootVariablesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Toolbox Action"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Lock Bootloader?",
            isPresented: $showLockConfirm,
            titleVisibility: .visible
        ) {
            Button("Lock Bootloader", role: .destructive) {
                executeLockBootloader()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("WARNING: Only lock the bootloader if official, unmodified firmware is installed on the active slot! Locking will wipe user data.")
        }
        .confirmationDialog(
            "Unlock Bootloader?",
            isPresented: $showUnlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Unlock Bootloader", role: .destructive) {
                executeUnlockBootloader()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("WARNING: Unlocking the bootloader will completely factory reset and wipe your device! Confirm on device screen.")
        }
    }

    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fastboot Reboot Modes", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .font(.headline)

            HStack(spacing: 10) {
                rebootButton(title: "Reboot Bootloader", icon: "wrench.and.screwdriver", target: "bootloader")
                rebootButton(title: "Reboot Fastbootd", icon: "cpu", target: "fastboot")
                rebootButton(title: "Reboot Recovery", icon: "cross.case", target: "recovery")
                rebootButton(title: "Reboot System", icon: "arrow.clockwise", target: nil)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func rebootButton(title: String, icon: String, target: String?) -> some View {
        Button(action: {
            guard let dev = monitor.selectedDevice else { return }
            Task {
                do {
                    _ = try await FastbootService.shared.reboot(serial: dev.serial, target: target)
                    alertMessage = "Reboot command sent to \(dev.displayName)."
                    showAlert = true
                } catch {
                    alertMessage = "Reboot failed: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .disabled(monitor.selectedDevice == nil)
    }

    // MARK: - Bootloader Security Section
    private var bootloaderSecuritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bootloader State & Controls", systemImage: "lock.shield.fill")
                .font(.headline)

            HStack(spacing: 14) {
                // Unlock
                Button(action: { showUnlockConfirm = true }) {
                    Label("Unlock Bootloader", systemImage: "lock.open.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(monitor.selectedDevice == nil)

                // Lock
                Button(action: { showLockConfirm = true }) {
                    Label("Lock Bootloader", systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .disabled(monitor.selectedDevice == nil)
            }

            Text("Note: Any lock or unlock command requires physical confirmation on the Pixel screen with Volume and Power buttons.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Slot & Partition Section
    private var slotAndPartitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("A/B Slot Switcher & Partition Tools", systemImage: "square.split.2x1")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Set Slot A Active") {
                    switchActiveSlot(to: "a")
                }
                .buttonStyle(.bordered)

                Button("Set Slot B Active") {
                    switchActiveSlot(to: "b")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Erase Userdata") {
                    eraseUserdata()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Variables Inspector
    private var fastbootVariablesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Device Fastboot Variables (`getvar all`)", systemImage: "list.bullet.rectangle")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter variables...", text: $searchVarQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 140)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)

                Button(action: fetchVariables) {
                    HStack(spacing: 4) {
                        if isLoadingVars {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Query Variables")
                    }
                }
                .disabled(monitor.selectedDevice == nil || isLoadingVars)
            }

            if deviceVariables.isEmpty {
                Text("Click 'Query Variables' to inspect device bootloader variables (serial, partitions, slots, secure boot).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
            } else {
                VStack(spacing: 2) {
                    ForEach(filteredVariables, id: \.key) { item in
                        HStack {
                            Text(item.key)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Spacer()

                            Text(item.value)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func switchActiveSlot(to slot: String) {
        guard let dev = monitor.selectedDevice else { return }
        Task {
            do {
                _ = try await FastbootService.shared.setActiveSlot(serial: dev.serial, slot: slot)
                alertMessage = "Active slot switched to Slot \(slot.uppercased())."
                showAlert = true
                await monitor.scanDevices()
            } catch {
                alertMessage = "Slot switch failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func eraseUserdata() {
        guard let dev = monitor.selectedDevice else { return }
        Task {
            do {
                _ = try await FastbootService.shared.erasePartition(serial: dev.serial, partition: "userdata")
                alertMessage = "Userdata partition erased."
                showAlert = true
            } catch {
                alertMessage = "Erase failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func executeLockBootloader() {
        guard let dev = monitor.selectedDevice else { return }
        Task {
            do {
                let isLegacy = (dev.matchedDevice?.releaseYear ?? 2024) <= 2017
                _ = try await FastbootService.shared.lockBootloader(serial: dev.serial, isLegacy: isLegacy)
                alertMessage = "Lock command executed. Confirm on Pixel display!"
                showAlert = true
            } catch {
                alertMessage = "Failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func executeUnlockBootloader() {
        guard let dev = monitor.selectedDevice else { return }
        Task {
            do {
                let isLegacy = (dev.matchedDevice?.releaseYear ?? 2024) <= 2017
                _ = try await FastbootService.shared.unlockBootloader(serial: dev.serial, isLegacy: isLegacy)
                alertMessage = "Unlock command executed. Confirm on Pixel display!"
                showAlert = true
            } catch {
                alertMessage = "Failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func fetchVariables() {
        guard let dev = monitor.selectedDevice else { return }
        isLoadingVars = true
        Task {
            let vars = await FastbootService.shared.getAllVars(serial: dev.serial)
            self.deviceVariables = vars
            self.isLoadingVars = false
        }
    }
}
