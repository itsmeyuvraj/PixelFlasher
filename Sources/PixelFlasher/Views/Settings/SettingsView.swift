import SwiftUI

public struct SettingsView: View {
    @State private var fastbootPath = ""
    @State private var adbPath = ""
    @State private var isDownloadingTools = false
    @State private var downloadToolsMessage = ""
    @State private var toolVersion = ""
    @State private var isReady = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings & Android Platform-Tools")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Configure adb and fastboot binaries, and download official Google tools.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 10)

                // Tool status banner
                statusCard

                // Path Configuration
                pathsCard

                // About & Official Google Documentation
                aboutCard
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .onAppear {
            refreshToolStatus()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Platform Tools"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Platform Tools Status", systemImage: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(isReady ? .green : .orange)

            Text(isReady ? "Ready: Fastboot and ADB were detected on your Mac." : "Warning: ADB or Fastboot is missing.")
                .font(.subheadline)

            if !toolVersion.isEmpty {
                Text(toolVersion)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if !isReady {
                Button(action: downloadTools) {
                    HStack(spacing: 6) {
                        if isDownloadingTools {
                            ProgressView().controlSize(.small)
                            Text(downloadToolsMessage)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Official Google Platform-Tools (macOS)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDownloadingTools)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isReady ? Color.green.opacity(0.2) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var pathsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Custom Tool Executables", systemImage: "folder.badge.gearshape")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Fastboot Executable Path:")
                    .font(.caption)
                    .fontWeight(.medium)
                TextField("/opt/homebrew/bin/fastboot", text: $fastbootPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ADB Executable Path:")
                    .font(.caption)
                    .fontWeight(.medium)
                TextField("/opt/homebrew/bin/adb", text: $adbPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Button("Save Paths") {
                    saveCustomPaths()
                }
                .buttonStyle(.borderedProminent)

                Button("Reset to System Default") {
                    fastbootPath = ""
                    adbPath = ""
                    saveCustomPaths()
                }
                .buttonStyle(.bordered)
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

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("About Pixel Flasher & Google Firmware", systemImage: "info.circle.fill")
                .font(.headline)

            Text("Pixel Flasher is a native macOS utility built with SwiftUI designed to flash official Google factory images, Full OTA packages, and Android Beta preview builds on all Google Pixel devices (Pixel 1 to Pixel 9 Pro Fold).")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://developers.google.com/android/images")!) {
                    Label("Google Factory Images", systemImage: "link")
                }
                Link(destination: URL(string: "https://developers.google.com/android/ota")!) {
                    Label("Google Full OTA Images", systemImage: "link")
                }
                Link(destination: URL(string: "https://developer.android.com/about/versions")!) {
                    Label("Android Beta Program", systemImage: "link")
                }
            }
            .font(.caption)
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

    private func refreshToolStatus() {
        Task {
            _ = await PlatformToolsManager.shared.detectTools()
            let ready = await PlatformToolsManager.shared.isReady
            let ver = await PlatformToolsManager.shared.toolVersion
            let fb = await PlatformToolsManager.shared.getFastbootPath()
            let adb = await PlatformToolsManager.shared.getAdbPath()

            self.isReady = ready
            self.toolVersion = ver
            self.fastbootPath = fb
            self.adbPath = adb
        }
    }

    private func saveCustomPaths() {
        Task {
            _ = await PlatformToolsManager.shared.detectTools(
                customAdb: adbPath.isEmpty ? nil : adbPath,
                customFastboot: fastbootPath.isEmpty ? nil : fastbootPath
            )
            refreshToolStatus()
            alertMessage = "Tool paths updated."
            showAlert = true
        }
    }

    private func downloadTools() {
        isDownloadingTools = true
        Task {
            do {
                try await PlatformToolsManager.shared.downloadGooglePlatformTools { _, msg in
                    Task { @MainActor in
                        self.downloadToolsMessage = msg
                    }
                }
                refreshToolStatus()
                alertMessage = "Google Platform-Tools installed successfully."
                showAlert = true
            } catch {
                alertMessage = "Download failed: \(error.localizedDescription)"
                showAlert = true
            }
            self.isDownloadingTools = false
        }
    }
}
