import SwiftUI
import UniformTypeIdentifiers

public struct OTASideloadView: View {
    @ObservedObject var monitor = DeviceMonitor.shared
    @ObservedObject var engine = FlashingEngine.shared

    @State private var selectedOTAURL: URL?
    @State private var showFilePicker = false
    @State private var isSideloading = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DeviceHeaderView()

                // Guide banner
                guideCard

                // File selection
                fileSelectionCard

                // Sideload Button & Status
                actionCard

                if engine.isFlashing || !engine.consoleLogs.isEmpty {
                    LiveConsoleView()
                        .frame(minHeight: 240)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                self.selectedOTAURL = url
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("OTA Sideload"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How to Flash a Full OTA Image", systemImage: "questionmark.circle.fill")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 6) {
                stepRow(number: "1", text: "Ensure your Pixel has USB Debugging enabled, or boot directly into Recovery mode.")
                stepRow(number: "2", text: "In Android Recovery: If you see 'No command', hold Power and tap Volume Up once.")
                stepRow(number: "3", text: "Use Volume keys to select 'Apply update from ADB' and press Power to confirm.")
                stepRow(number: "4", text: "Select your downloaded OTA .zip below and click 'Start ADB Sideload'.")
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

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var fileSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Full OTA Package", systemImage: "doc.zipper")
                .font(.headline)
                .foregroundColor(.primary)

            if let url = selectedOTAURL {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button("Change") {
                        showFilePicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .cornerRadius(8)
            } else {
                Button(action: { showFilePicker = true }) {
                    Label("Choose OTA Package (.zip)", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
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

    private var actionCard: some View {
        VStack(spacing: 10) {
            Button(action: startSideload) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.headline)
                    Text("Start ADB Sideload")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(selectedOTAURL == nil || monitor.selectedDevice == nil || engine.isFlashing)

            if engine.isFlashing {
                VStack(spacing: 6) {
                    ProgressView(value: engine.progressFraction)
                    Text(engine.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private func startSideload() {
        guard let dev = monitor.selectedDevice, let otaURL = selectedOTAURL else { return }

        Task {
            do {
                try await engine.flashOTAImage(device: dev, firmwareURL: otaURL)
            } catch {
                self.alertMessage = error.localizedDescription
                self.showAlert = true
            }
        }
    }
}
