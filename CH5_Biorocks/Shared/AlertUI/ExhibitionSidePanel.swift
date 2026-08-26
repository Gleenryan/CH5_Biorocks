import SwiftUI

/// Side panel used next to maps — points visitors at the Python exhibition visualizer
/// and shows a simple confidence / status strip for the current alert or hydrophone.
struct ExhibitionSidePanel: View {
    var title: String = "Acoustic scene"
    var detail: String = "Live spectrograms run in the separate Python exhibition window. Coralyst shows detections and site context here."
    var confidence: Double? = nil
    var accent: Color = Color(red: 0.24, green: 0.81, blue: 0.70)

    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmer = false

    private var panelBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.09, blue: 0.12)
            : Color(red: 0.93, green: 0.96, blue: 0.95)
    }

    var body: some View {
        ZStack {
            panelBackground

            // Soft moving wash — visual interest without competing with the map.
            LinearGradient(
                colors: [
                    accent.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    .clear,
                    accent.opacity(colorScheme == .dark ? 0.08 : 0.05)
                ],
                startPoint: shimmer ? .topLeading : .bottomTrailing,
                endPoint: shimmer ? .bottomTrailing : .topLeading
            )
            .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: shimmer)

            VStack(alignment: .leading, spacing: 14) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(accent)

                Text(detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let confidence {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(accent.gradient)
                                    .frame(width: max(8, geo.size.width * confidence))
                            }
                        }
                        .frame(height: 10)
                        Text(String(format: "%.0f%%", confidence * 100))
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }

                Spacer(minLength: 0)

                Label("Python exhibit  ·  Coralyst results", systemImage: "rectangle.split.2x1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .accessibilityLabel("Exhibition acoustic scene panel")
        .onAppear { shimmer = true }
    }
}
