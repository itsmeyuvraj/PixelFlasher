import SwiftUI

public struct LiveConsoleView: View {
    @ObservedObject var engine = FlashingEngine.shared
    @State private var filterQuery = ""
    @State private var autoScroll = true
    @State private var showExportSuccess = false

    public init() {}

    private var filteredLogs: [ConsoleLogEntry] {
        if filterQuery.isEmpty {
            return engine.consoleLogs
        }
        return engine.consoleLogs.filter { $0.message.localizedCaseInsensitiveContains(filterQuery) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Label("Flashing Terminal Console", systemImage: "terminal.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Filter search
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter logs...", text: $filterQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 130)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Button(action: { engine.clearLogs() }) {
                    Image(systemName: "trash")
                }
                .help("Clear Terminal Logs")

                Button(action: exportLogs) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export Logs to File")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Console output area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if filteredLogs.isEmpty {
                            Text(engine.consoleLogs.isEmpty ? "No logs yet. Flash operations or device commands will stream output here." : "No logs matching filter.")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(filteredLogs) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(timeString(entry.timestamp))
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .frame(width: 65, alignment: .leading)

                                    Text(entry.message)
                                        .font(.system(size: 11, weight: entry.isHighlighted ? .bold : .regular, design: .monospaced))
                                        .foregroundColor(logColor(entry))
                                        .textSelection(.enabled)

                                    Spacer()
                                }
                                .id(entry.id)
                            }
                        }
                    }
                    .padding(10)
                }
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
                .onChange(of: engine.consoleLogs.count) {
                    if autoScroll, let last = engine.consoleLogs.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func logColor(_ entry: ConsoleLogEntry) -> Color {
        if entry.isError || entry.message.contains("FAILED") || entry.message.contains("Error") {
            return Color.red
        }
        if entry.message.contains("OKAY") || entry.message.contains("success") || entry.message.contains("Verified") {
            return Color.green
        }
        if entry.message.contains("Sending '") || entry.message.contains("Writing '") {
            return Color.cyan
        }
        if entry.message.contains("WARNING") || entry.message.contains("Warning") {
            return Color.yellow
        }
        if entry.isHighlighted {
            return Color.white
        }
        return Color(red: 0.85, green: 0.85, blue: 0.88)
    }

    private func exportLogs() {
        let allText = engine.consoleLogs.map { "[\(timeString($0.timestamp))] \($0.message)" }.joined(separator: "\n")
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "PixelFlasher_Log_\(Int(Date().timeIntervalSince1970)).txt"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? allText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
