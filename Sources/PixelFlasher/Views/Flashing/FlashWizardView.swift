import SwiftUI
import UniformTypeIdentifiers

public struct FlashWizardView: View {
    @ObservedObject var monitor = DeviceMonitor.shared
    @ObservedObject var engine = FlashingEngine.shared

    @State private var configuration = FlashConfiguration(
        wipeUserData: false,
        lockBootloader: false,
        forceFlashBothSlots: false,
        rebootAfterFlash: true,
        verifyImageIntegrity: true,
        verifyPostFlashState: true
    )

    @State private var selectedLocalURL: URL?
    @State private var showConfirmDialog = false
    @State private var showFilePicker = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top device status banner
                DeviceHeaderView()

                if engine.isFlashing || engine.currentStage == .completed || engine.currentStage == .failed {
                    // Active flashing progress & console
                    FlashingProgressView()
                    LiveConsoleView()
                        .frame(minHeight: 260)
                } else {
                    // Configuration & Options Cards
                    firmwareSelectionCard
                    flashingOptionsCard
                    actionButtonSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.zip, UTType.archive],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    self.selectedLocalURL = url
                    self.configuration.localFirmwareURL = url
                    self.configuration.selectedRelease = nil
                }
            case .failure(let err):
                self.errorMessage = "Failed to select file: \(err.localizedDescription)"
                self.showErrorAlert = true
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? "An error occurred."), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Confirm Firmware Flashing",
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Yes, Flash Device", role: .destructive) {
                startFlashing()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }

    // MARK: - Firmware Selection Card
    private var firmwareSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("1. Select Firmware Image", systemImage: "archivebox.fill")
                .font(.headline)
                .foregroundColor(.primary)

            if let release = configuration.selectedRelease {
                // Catalog release selected
                HStack(spacing: 14) {
                    Image(systemName: release.type.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(release.versionName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Device: \(release.deviceCodename) • Build: \(release.buildId) • \(release.type.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("SHA-256: \(release.sha256.prefix(16))...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Change") {
                        configuration.selectedRelease = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(8)
            } else if let localURL = selectedLocalURL {
                // Local file selected
                HStack(spacing: 14) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localURL.lastPathComponent)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Path: \(localURL.path)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button("Choose Another") {
                        showFilePicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(8)
            } else {
                // No firmware selected yet: choose file or pick from catalog
                HStack(spacing: 12) {
                    Button(action: { showFilePicker = true }) {
                        Label("Select Local Firmware (.zip)", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    if let dev = monitor.selectedDevice, let codename = dev.productCodename {
                        let releases = FirmwareCatalogService.shared.releasesFor(deviceCodename: codename)
                        if let firstRelease = releases.first {
                            Button(action: {
                                self.configuration.selectedRelease = firstRelease
                            }) {
                                Label("Use Official \(firstRelease.androidVersion)", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
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
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Flashing Options Card
    private var flashingOptionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("2. Flashing Options & Safety Rules", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                // Option 1: Wipe User Data
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $configuration.wipeUserData) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Erase / Wipe User Data (Factory Reset)")
                                .fontWeight(.semibold)
                            Text("Enables '-w' flag in fastboot. Completely wipes userdata and cache.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if configuration.wipeUserData {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("WARNING: All personal photos, apps, accounts, and internal storage will be erased!")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                    }
                }

                Divider()

                // Option 2: Lock Bootloader After Flashing
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $configuration.lockBootloader) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lock Bootloader After Flashing")
                                .fontWeight(.semibold)
                            Text("Executes 'fastboot flashing lock' after all partitions are verified.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if configuration.lockBootloader {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Notice: Re-locking will trigger an on-screen prompt on your Pixel. You must press Volume Down and Power to confirm on device.")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }
                }

                Divider()

                // Option 3: Verify Integrity & Flashed State
                Toggle(isOn: $configuration.verifyImageIntegrity) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verify Image Integrity & Checksum")
                            .fontWeight(.semibold)
                        Text("Verifies SHA-256 hash against official Google checksum and confirms device codename compatibility.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                // Option 4: Post-Flash Verification
                Toggle(isOn: $configuration.verifyPostFlashState) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verify Post-Flash Device State")
                            .fontWeight(.semibold)
                        Text("Validates partition write status, active boot slot health, and bootloader version.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                // Option 5: Force Flash Both Slots
                Toggle(isOn: $configuration.forceFlashBothSlots) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force Flash Both Slots (A & B)")
                            .fontWeight(.semibold)
                        Text("Uses '--slot=all' for full redundancy across both slots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                // Option 6: Auto Reboot
                Toggle(isOn: $configuration.rebootAfterFlash) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Reboot After Flash")
                            .fontWeight(.semibold)
                        Text("Automatically boots your Pixel into the freshly flashed Android OS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
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

    // MARK: - Action Button Section
    private var actionButtonSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                showConfirmDialog = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                    Text("Flash Official Firmware")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(configuration.wipeUserData ? .orange : .blue)
            .disabled(!isReadyToFlash)

            if !isReadyToFlash {
                Text(missingRequirementsReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var isReadyToFlash: Bool {
        guard monitor.selectedDevice != nil else { return false }
        return configuration.selectedRelease != nil || selectedLocalURL != nil
    }

    private var missingRequirementsReason: String {
        if monitor.selectedDevice == nil {
            return "Please connect a Google Pixel device to proceed."
        }
        if configuration.selectedRelease == nil && selectedLocalURL == nil {
            return "Please select a firmware image (.zip) or choose from the catalog above."
        }
        return ""
    }

    private var confirmationMessage: String {
        var msg = "Are you sure you want to flash this firmware?\n"
        if let dev = monitor.selectedDevice {
            msg += "\nDevice: \(dev.displayName)"
        }
        if configuration.wipeUserData {
            msg += "\n• ALL DATA WILL BE WIPED (Clean Flash)."
        } else {
            msg += "\n• Data will be preserved (Dirty Flash)."
        }
        if configuration.lockBootloader {
            msg += "\n• Bootloader will be locked after flashing."
        }
        return msg
    }

    private func startFlashing() {
        guard let device = monitor.selectedDevice else { return }

        Task {
            var targetFirmwareURL: URL? = selectedLocalURL

            // If a catalog release was chosen without local file, check if already downloaded or download
            if let release = configuration.selectedRelease, targetFirmwareURL == nil {
                do {
                    targetFirmwareURL = try await FirmwareDownloader.shared.download(release: release) { _ in }
                } catch {
                    self.errorMessage = "Download error: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    return
                }
            }

            guard let fwURL = targetFirmwareURL else {
                self.errorMessage = "Firmware file could not be prepared."
                self.showErrorAlert = true
                return
            }

            do {
                _ = try await engine.flashFactoryImage(
                    device: device,
                    firmwareURL: fwURL,
                    configuration: configuration
                )
            } catch {
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
        }
    }
}
