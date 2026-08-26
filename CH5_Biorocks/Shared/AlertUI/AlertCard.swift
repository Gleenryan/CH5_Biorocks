import SwiftUI

/// Shared alert summary card with a modern, elevated aesthetic and generous breathing room.
struct AlertCard: View {
    let alert: AlertSummary
    let primaryText: Color
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var severityColor: Color {
        switch alert.severity.lowercased() {
        case "high":
            return Color(hex: "EF4444") // Coral Red
        case "medium":
            return Color(hex: "F59E0B") // Amber
        default:
            return Color(hex: "0EA5E9") // Sky Blue
        }
    }

    private var severityIcon: String {
        switch alert.severity.lowercased() {
        case "high":
            return "exclamationmark.triangle.fill"
        case "medium":
            return "waveform.badge.exclamationmark"
        default:
            return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Accent Indicator Bar
            Rectangle()
                .fill(severityColor)
                .frame(width: 4.5)

            VStack(alignment: .leading, spacing: 12) {
                // Header: Title & Severity Pill
                HStack(alignment: .center, spacing: 10) {
                    Text(alert.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        Image(systemName: severityIcon)
                            .font(.system(size: 10, weight: .bold))
                        Text(alert.severity.uppercased())
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(severityColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(severityColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
                }

                // Subtitle / Location & Meta
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(severityColor.opacity(0.85))
                    Text(alert.detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Description Body
                Text(alert.message)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.75))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isHovered ? severityColor.opacity(0.5) : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? (isHovered ? 0.3 : 0.15) : (isHovered ? 0.08 : 0.03)),
            radius: isHovered ? 8 : 4,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    AlertCard(
        alert: AlertSummary.preview[0],
        primaryText: .primary
    )
    .frame(width: 380)
    .padding()
}
