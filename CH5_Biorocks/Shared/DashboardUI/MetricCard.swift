import SwiftUI

/// Reusable dashboard metric presentation used by Site and Hydrophone screens.
struct MetricCard: View {
    let title: String
    let value: String
    let trend: String?
    let status: String
    let trendIsPositive: Bool
    let primaryText: Color
    var isProminent: Bool = false

    private var statusTint: Color {
        switch status {
        case "Check needed": .red
        case "No data", "Awaiting data": .secondary
        default: .green
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.callout)
                .foregroundStyle(primaryText)
                .lineLimit(1)
            Spacer()

            HStack(alignment: .center, spacing: 7) {
                Text(value)
                    .font(.system(size: isProminent ? 68 : 48, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if let trend {
                    let displayTrend = trend
                        .replacingOccurrences(of: "+", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "−", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    Spacer()
                    
                    Label(displayTrend, systemImage: trendIsPositive ? "chevron.up" : "chevron.down")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(trendIsPositive ? .green : .red)
                        .labelStyle(.titleAndIcon)
                }
            }
            Spacer()

            Text(status)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(statusTint, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .frame(
            maxWidth: 180,
            minHeight: isProminent ? 224 : 140,
            maxHeight: isProminent ? 224 : 140,
            alignment: .topLeading
        )
        .background(Color(hex: "C7F5FF"), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
    }
}

#Preview {
    MetricCard(
        title: "Health Composition",
        value: "80",
        trend: "+ 2",
        status: "Healthy",
        trendIsPositive: true,
        primaryText: .primary
    )
    .padding()
}
