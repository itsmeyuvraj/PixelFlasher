import SwiftUI

public struct FirmwareBrowserView: View {
    @ObservedObject var monitor = DeviceMonitor.shared
    @ObservedObject var catalog = FirmwareCatalogService.shared

    @State private var selectedDeviceCodename: String = "bluejay" // Default to Pixel 6a
    @State private var selectedType: FirmwareType = .factory
    @State private var selectedAndroidVersion: String = "All"
    @State private var searchQuery = ""
    @State private var downloadingReleaseId: String?
    @State private var downloadProgress: DownloadProgress?
    @State private var downloadedURLs: [String: URL] = [:]
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showAddCustomReleaseSheet = false

    // Form fields for adding custom release
    @State private var customVersionName = ""
    @State private var customBuildId = ""
    @State private var customAndroidVersion = "Android 17"
    @State private var customType: FirmwareType = .factory
    @State private var customDownloadURL = ""
    @State private var customSHA256 = ""
    @State private var customSecurityPatch = "2026-03-05"

    public init() {}

    private var currentReleases: [FirmwareRelease] {
        var list = catalog.releasesFor(
            deviceCodename: selectedDeviceCodename,
            type: selectedType,
            androidVersion: selectedAndroidVersion == "All" ? nil : selectedAndroidVersion
        )
        if !searchQuery.isEmpty {
            list = list.filter {
                $0.versionName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.buildId.localizedCaseInsensitiveContains(searchQuery) ||
                $0.androidVersion.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        return list
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Controls Bar
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Device Picker
                    Picker("Pixel Device:", selection: $selectedDeviceCodename) {
                        ForEach(PixelDevice.generations, id: \.self) { gen in
                            Section(header: Text(gen)) {
                                ForEach(PixelDevice.allDevices.filter { $0.generation == gen }) { dev in
                                    Text("\(dev.name) (\(dev.codename))").tag(dev.codename)
                                }
                            }
                        }
                    }
                    .frame(width: 270)

                    // Auto-select detected device button
                    if let dev = monitor.selectedDevice, let codename = dev.productCodename {
                        Button(action: {
                            selectedDeviceCodename = codename
                        }) {
                            Label("Use Connected (\(codename))", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    // Android Version Filter
                    Picker("Version:", selection: $selectedAndroidVersion) {
                        Text("All Versions").tag("All")
                        Text("Android 17").tag("Android 17")
                        Text("Android 16").tag("Android 16")
                        Text("Android 15").tag("Android 15")
                    }
                    .frame(width: 170)

                    Spacer()

                    // Add Custom Firmware Button
                    Button(action: { showAddCustomReleaseSheet = true }) {
                        Label("Add Custom Build", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // Search field
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search builds...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .frame(width: 130)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                }

                // Firmware Type Tabs (Factory, OTA, Beta)
                Picker("", selection: $selectedType) {
                    ForEach(FirmwareType.allCases) { type in
                        Label(type.rawValue, systemImage: type.iconName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Release List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if currentReleases.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(currentReleases) { release in
                            releaseCard(release)
                        }
                    }
                }
                .padding(14)
            }
        }
        .onAppear {
            if let dev = monitor.selectedDevice, let codename = dev.productCodename {
                selectedDeviceCodename = codename
            }
        }
        .sheet(isPresented: $showAddCustomReleaseSheet) {
            addCustomReleaseSheet
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Download"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 44))
                .foregroundColor(.secondary)

            Text("No releases found for \(selectedDeviceCodename) under \(selectedType.rawValue) (\(selectedAndroidVersion))")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Try switching firmware categories, changing the Android version filter, or click 'Add Custom Build' above.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func releaseCard(_ release: FirmwareRelease) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(release.versionName)
                            .font(.headline)
                            .fontWeight(.bold)

                        // Android Version Badge
                        Text(release.androidVersion)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(versionBadgeColor(release.androidVersion))
                            .foregroundColor(.white)
                            .clipShape(Capsule())

                        if release.isBeta {
                            Text("BETA / PREVIEW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 12) {
                        Label("Device: \(release.deviceCodename)", systemImage: "iphone")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Build: \(release.buildId)", systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Patch: \(release.securityPatch)", systemImage: "shield.checkerboard")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Size: ~\(release.approximateSizeMB) MB", systemImage: "doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Download / Flash Buttons
                if downloadingReleaseId == release.id {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView().controlSize(.small)
                        if let p = downloadProgress {
                            Text("\(p.progressPercentageString) • \(p.speedString)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let downloadedURL = downloadedURLs[release.id] {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Downloaded")
                            .font(.caption)
                            .fontWeight(.medium)

                        Button("Flash") {
                            prepareAndFlash(release: release, url: downloadedURL)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button("Download") {
                            startDownload(release: release)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Download & Flash") {
                            startDownloadAndFlash(release: release)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            // Checksum info line
            HStack(spacing: 8) {
                Text("SHA-256:")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(release.sha256)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(release.sha256, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Copy SHA-256 Checksum")
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func versionBadgeColor(_ ver: String) -> Color {
        if ver.contains("17") {
            return Color.blue
        } else if ver.contains("16") {
            return Color.teal
        } else if ver.contains("15") {
            return Color.indigo
        } else {
            return Color.gray
        }
    }

    // MARK: - Add Custom Release Sheet
    private var addCustomReleaseSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Add Custom Firmware Build / Direct URL", systemImage: "plus.circle.fill")
                    .font(.headline)
                Spacer()
                Button("Close") { showAddCustomReleaseSheet = false }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Text("Enter details for any official Google release, Android 17 preview, or custom build:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version Name:")
                            .font(.caption)
                        TextField("e.g. Android 17.0.0 (CP11.260210.006)", text: $customVersionName)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build ID:")
                            .font(.caption)
                        TextField("e.g. CP11.260210.006", text: $customBuildId)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Android Version:")
                            .font(.caption)
                        TextField("e.g. Android 17", text: $customAndroidVersion)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Release Type:")
                            .font(.caption)
                        Picker("", selection: $customType) {
                            ForEach(FirmwareType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Download URL:")
                        .font(.caption)
                    TextField("https://dl.google.com/dl/android/aosp/...", text: $customDownloadURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("SHA-256 Checksum (Optional):")
                        .font(.caption)
                    TextField("64-character SHA-256 hash...", text: $customSHA256)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Spacer()
                Button("Save and Add to Catalog") {
                    saveCustomRelease()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customDownloadURL.isEmpty || customBuildId.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func saveCustomRelease() {
        guard let url = URL(string: customDownloadURL.trimmingCharacters(in: .whitespaces)) else { return }

        let rel = FirmwareRelease(
            deviceCodename: selectedDeviceCodename,
            versionName: customVersionName.isEmpty ? "\(customAndroidVersion) (\(customBuildId))" : customVersionName,
            buildId: customBuildId,
            androidVersion: customAndroidVersion,
            type: customType,
            downloadURL: url,
            sha256: customSHA256.isEmpty ? "0000000000000000000000000000000000000000000000000000000000000000" : customSHA256,
            releaseDate: "2026",
            securityPatch: customSecurityPatch,
            approximateSizeMB: 3000,
            isBeta: customType == .beta || customAndroidVersion.contains("Beta")
        )

        catalog.addCustomRelease(rel)
        showAddCustomReleaseSheet = false
    }

    private func startDownload(release: FirmwareRelease) {
        self.downloadingReleaseId = release.id
        Task {
            do {
                let url = try await FirmwareDownloader.shared.download(release: release) { prog in
                    Task { @MainActor in
                        self.downloadProgress = prog
                    }
                }
                self.downloadedURLs[release.id] = url
                self.downloadingReleaseId = nil
                self.alertMessage = "Downloaded to: \(url.path)"
                self.showAlert = true
            } catch {
                self.downloadingReleaseId = nil
                self.alertMessage = "Download failed: \(error.localizedDescription)"
                self.showAlert = true
            }
        }
    }

    private func startDownloadAndFlash(release: FirmwareRelease) {
        self.downloadingReleaseId = release.id
        Task {
            do {
                let url = try await FirmwareDownloader.shared.download(release: release) { prog in
                    Task { @MainActor in
                        self.downloadProgress = prog
                    }
                }
                self.downloadedURLs[release.id] = url
                self.downloadingReleaseId = nil
                prepareAndFlash(release: release, url: url)
            } catch {
                self.downloadingReleaseId = nil
                self.alertMessage = "Download error: \(error.localizedDescription)"
                self.showAlert = true
            }
        }
    }

    private func prepareAndFlash(release: FirmwareRelease, url: URL) {
        guard let dev = monitor.selectedDevice else {
            alertMessage = "No device connected to flash."
            showAlert = true
            return
        }

        let config = FlashConfiguration(
            wipeUserData: false,
            lockBootloader: false,
            forceFlashBothSlots: false,
            rebootAfterFlash: true,
            verifyImageIntegrity: true,
            verifyPostFlashState: true,
            localFirmwareURL: url,
            selectedRelease: release
        )

        Task {
            _ = try? await FlashingEngine.shared.flashFactoryImage(
                device: dev,
                firmwareURL: url,
                configuration: config
            )
        }
    }
}
