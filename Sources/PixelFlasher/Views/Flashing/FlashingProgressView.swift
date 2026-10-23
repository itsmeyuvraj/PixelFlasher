import SwiftUI

public struct FlashingProgressView: View {
    @ObservedObject var engine = FlashingEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            // Stage and Partition status
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stageColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: engine.currentStage.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(stageColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(engine.currentStage.rawValue)
                            .font(.headline)
                            .fontWeight(.semibold)

                        if let part = engine.currentPartition, engine.isFlashing {
                            Text("Writing: \(part)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(engine.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Percentage indicator
                Text(String(format: "%.0f%%", engine.progressFraction * 100))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(stageColor)
            }

            // Custom Smooth Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [stageColor.opacity(0.8), stageColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width * engine.progressFraction, geo.size.width)), height: 10)
                        .animation(.easeInOut(duration: 0.25), value: engine.progressFraction)
                }
            }
            .frame(height: 10)

            // Step pipeline indicators
            HStack(spacing: 4) {
                pipelineStep(title: "Verify", active: engine.progressFraction >= 0.05, completed: engine.progressFraction > 0.15)
                pipelineDivider(active: engine.progressFraction > 0.15)
                pipelineStep(title: "Unpack", active: engine.progressFraction >= 0.25, completed: engine.progressFraction > 0.30)
                pipelineDivider(active: engine.progressFraction > 0.30)
                pipelineStep(title: "Bootloader", active: engine.progressFraction >= 0.35, completed: engine.progressFraction > 0.40)
                pipelineDivider(active: engine.progressFraction > 0.40)
                pipelineStep(title: "Radio", active: engine.progressFraction >= 0.45, completed: engine.progressFraction > 0.55)
                pipelineDivider(active: engine.progressFraction > 0.55)
                pipelineStep(title: "System", active: engine.progressFraction >= 0.60, completed: engine.progressFraction > 0.85)
                pipelineDivider(active: engine.progressFraction > 0.85)
                pipelineStep(title: "Verify & Finish", active: engine.progressFraction >= 0.90, completed: engine.progressFraction >= 1.0)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stageColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var stageColor: Color {
        switch engine.currentStage {
        case .completed: return .green
        case .failed: return .red
        case .idle: return .accentColor
        default: return .blue
        }
    }

    private func pipelineStep(title: String, active: Bool, completed: Bool) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(completed ? Color.green : (active ? Color.blue : Color.secondary.opacity(0.2)))
                    .frame(width: 14, height: 14)

                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text(title)
                .font(.system(size: 9, weight: active ? .semibold : .regular))
                .foregroundColor(active ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func pipelineDivider(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.green : Color.secondary.opacity(0.2))
            .frame(height: 2)
            .frame(maxWidth: 16)
            .padding(.bottom, 12)
    }
}
