import SwiftUI

/// Reusable icon-and-value summary card with modern ocean-themed styling and generous spacing.
struct InfoItem: View {
    let title: String
    let value: String
    let systemImage: String
    let primaryText: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.coralystPrimary.opacity(colorScheme == .dark ? 0.25 : 0.15),
                                Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.coralystPrimary.opacity(0.2), lineWidth: 1)
                    )

                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)
            }

            // Labels
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 20) {
        InfoItem(
            title: "Active Hydrophones",
            value: "4/4",
            systemImage: "waveform",
            primaryText: .primary
        )
        InfoItem(
            title: "Depth Range",
            value: "4 – 15m",
            systemImage: "water.waves",
            primaryText: .primary
        )
    }
    .padding()
}
