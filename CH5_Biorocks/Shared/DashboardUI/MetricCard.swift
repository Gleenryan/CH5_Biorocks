import SwiftUI

/// Reusable dashboard metric presentation with modern Apple Pro styling and generous breathing room.
struct MetricCard: View {
    let title: String
    let value: String
    let trend: String?
    let status: String
    let trendIsPositive: Bool
    let primaryText: Color
    var isProminent: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var statusColor: Color {
        switch status.lowercased() {
        case "check needed", "critical", "danger":
            return Color(hex: "EF4444") // Red
        case "no data", "awaiting data":
            return Color(hex: "94A3B8") // Slate
        default:
            return Color(hex: "10B981") // Emerald / Mint
        }
    }

    private var metricIcon: String {
        switch title.lowercased() {
        case let t where t.contains("health"):
            return "heart.fill"
        case let t where t.contains("ndsi"):
            return "chart.bar.xaxis"
        case let t where t.contains("snap"):
            return "sparkles"
        case let t where t.contains("freq") || t.contains("dbfs"):
            return "waveform"
        case let t where t.contains("bomb") || t.contains("alert"):
            return "shield.checkered"
        case let t where t.contains("biophony"):
            return "leaf.fill"
        default:
            return "gauge.with.needle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Row: Title + Metric Icon
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: metricIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary.opacity(0.85))
            }

            Spacer(minLength: 12)

            // Middle Row: Big Value + Trend Pill
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(value)
                    .font(.system(size: isProminent ? 58 : 38, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let trend, !trend.trimmingCharacters(in: .whitespaces).isEmpty {
                    let displayTrend = trend
                        .replacingOccurrences(of: "+", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "−", with: "")
                        .trimmingCharacters(in: .whitespaces)

                    Spacer(minLength: 4)

                    HStack(spacing: 3) {
                        Image(systemName: trendIsPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(displayTrend)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(trendIsPositive ? Color(hex: "10B981") : Color(hex: "EF4444"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        (trendIsPositive ? Color(hex: "10B981") : Color(hex: "EF4444"))
                            .opacity(colorScheme == .dark ? 0.2 : 0.1),
                        in: Capsule()
                    )
                }
            }

            Spacer(minLength: 12)

            // Bottom Row: Status Pill with Dot
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(status)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                statusColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                in: Capsule()
            )
        }
        .padding(18)
        .frame(
            minWidth: 150,
            maxWidth: isProminent ? 230 : 210,
            minHeight: isProminent ? 300 : 142,
            maxHeight: isProminent ? 300 : 142,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isHovered ? Color.coralystPrimary.opacity(0.45) : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06),
                    lineWidth: 1
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? (isHovered ? 0.3 : 0.15) : (isHovered ? 0.08 : 0.03)),
            radius: isHovered ? 8 : 4,
            y: isHovered ? 3 : 1.5
        )
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    HStack(spacing: 18) {
        MetricCard(
            title: "Health Composition",
            value: "80",
            trend: "+ 2",
            status: "Healthy",
            trendIsPositive: true,
            primaryText: .primary
        )
        MetricCard(
            title: "NDSI",
            value: "0.78",
            trend: "+ 0.087",
            status: "Good",
            trendIsPositive: true,
            primaryText: .primary
        )
    }
    .padding()
}
