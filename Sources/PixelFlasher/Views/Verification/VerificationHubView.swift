import SwiftUI
import UniformTypeIdentifiers

public struct VerificationHubView: View {
    @ObservedObject var engine = FlashingEngine.shared
    @ObservedObject var monitor = DeviceMonitor.shared

    // Standalone verification tool state
    @State private var standaloneURL: URL?
    @State private var expectedHashInput = ""
    @State private var calculatedHash = ""
    @State private var isCalculating = false
    @State private var hashProgress: Double = 0.0
    @State private var showFilePicker = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                headerBanner

                // Section 1: Latest Flash Verification Report
                if let report = engine.latestReport {
                    latestReportSection(report)
                } else {
                    noReportBanner
                }

                Divider()

                // Section 2: Standalone Image & Checksum Verifier
                standaloneVerifierSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.zip, UTType.archive],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                self.standaloneURL = url
                self.calculatedHash = ""
            }
        }
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Firmware & Flash Verification Hub")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Verify image integrity before flashing, and check slot health and partition status after flashing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.top, 10)
    }

    // MARK: - Latest Report Section
    private func latestReportSection(_ report: VerificationReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Latest Flash Verification Report", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)

                Spacer()

                // Overall status badge
                HStack(spacing: 6) {
                    Image(systemName: report.overallStatus.icon)
                    Text(report.overallStatus.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor(report.overallStatus).opacity(0.15))
                .foregroundColor(statusColor(report.overallStatus))
                .clipShape(Capsule())
            }

            // Summary description
            Text(report.summaryMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Diagnostic Grid Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Pre-flash Card
                VStack(alignment: .leading, spacing: 8) {
                    Label("Pre-Flash Checks", systemImage: "shield.lefthalf.filled")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    checkRow(title: "SHA-256 Checksum", status: report.checksumStatus)
                    if let calc = report.calculatedChecksum {
                        Text("Hash: \(calc.prefix(12))...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    checkRow(title: "Codename Compatibility", status: report.codenameMatchStatus)
                    if let code = report.detectedDeviceCodename {
                        Text("Device: \(code)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // Post-flash Card
                VStack(alignment: .leading, spacing: 8) {
                    Label("Post-Flash Device Checks", systemImage: "iphone.radiowaves.left.and.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    checkRow(title: "Active Boot Slot", status: report.postFlashSlotStatus)
                    if let slot = report.currentSlot {
                        Text("Current Slot: \(slot.uppercased())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    checkRow(title: "Bootloader Firmware Match", status: report.bootloaderVersionMatches)
                    if let blVer = report.reportedBootloaderVersion {
                        Text("BL Ver: \(blVer)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let lockStatus = report.bootloaderLockedStatus {
                        checkRow(title: "Bootloader Lock State", status: lockStatus)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }

            // Partition write table
            if !report.partitionResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Partition Write Results")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    VStack(spacing: 4) {
                        ForEach(report.partitionResults) { part in
                            HStack {
                                Text(part.partitionName)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.medium)

                                Spacer()

                                Text(String(format: "%.1fs", part.timeElapsedSeconds))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Image(systemName: part.status.icon)
                                    .foregroundColor(statusColor(part.status))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
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

    private var noReportBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)

            Text("No flash verification report available yet. Complete a firmware flash to view verified device state and slot integrity.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Standalone Verifier Section
    private var standaloneVerifierSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Standalone Firmware File Verifier", systemImage: "checkmark.circle.badge.questionmark")
                .font(.headline)

            Text("Compute SHA-256 of any factory image or OTA file and compare it against Google's published checksum.")
                .font(.caption)
                .foregroundColor(.secondary)

            // File selection
            HStack(spacing: 10) {
                if let url = standaloneURL {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Change") { showFilePicker = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Button("Select Firmware File to Verify (.zip)") {
                        showFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Expected hash input
            HStack(spacing: 8) {
                Text("Expected SHA-256 (optional):")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Paste 64-character SHA-256 checksum...", text: $expectedHashInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            // Calculate button
            if standaloneURL != nil {
                Button(action: runChecksumCalculation) {
                    HStack(spacing: 6) {
                        if isCalculating {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "lock.shield")
                        }
                        Text(isCalculating ? "Calculating Hash..." : "Compute SHA-256 Checksum")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCalculating)
            }

            // Calculated Hash Result
            if !calculatedHash.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calculated SHA-256 Checksum:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    HStack(spacing: 8) {
                        Text(calculatedHash)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)

                        Spacer()

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(calculatedHash, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)

                    // Match comparison
                    if !expectedHashInput.isEmpty {
                        let isMatch = calculatedHash.trimmingCharacters(in: .whitespaces).lowercased() == expectedHashInput.trimmingCharacters(in: .whitespaces).lowercased()
                        HStack(spacing: 6) {
                            Image(systemName: isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isMatch ? .green : .red)
                            Text(isMatch ? "Checksum Verified: Matches expected hash!" : "CHECKSUM MISMATCH! File may be modified or incomplete.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isMatch ? .green : .red)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
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

    private func checkRow(title: String, status: CheckResultStatus) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: status.icon)
                Text(status.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(statusColor(status))
        }
    }

    private func statusColor(_ status: CheckResultStatus) -> Color {
        switch status {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .skipped: return .gray
        }
    }

    private func runChecksumCalculation() {
        guard let url = standaloneURL else { return }
        isCalculating = true
        calculatedHash = ""

        Task {
            do {
                let hash = try await VerificationService.shared.calculateSHA256(for: url) { prog in
                    Task { @MainActor in
                        self.hashProgress = prog
                    }
                }
                self.calculatedHash = hash
            } catch {
                self.calculatedHash = "Error: \(error.localizedDescription)"
            }
            self.isCalculating = false
        }
    }
}
