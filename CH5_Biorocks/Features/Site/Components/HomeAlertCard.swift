import SwiftUI

struct HomeAlertCard: View {
    let alert: HomeAlert
    let primaryText: Color

    private var tint: Color {
        switch alert.severity.lowercased() {
        case "high": .red
        case "medium": .orange
        default: .yellow
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(alert.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(alert.severity)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(tint, in: RoundedRectangle(cornerRadius: 6))
            }

            Label(alert.detail, systemImage: "location.fill")
                .font(.caption)

            Text(alert.message)
                .font(.callout)
                .lineLimit(4)

        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.85), lineWidth: 1)
        }
    }
}

#Preview {
    HomeAlertCard(
        alert: HomeAlert.preview[0],
        primaryText: .primary
    )
    .frame(width: 400)
    .padding()
}
