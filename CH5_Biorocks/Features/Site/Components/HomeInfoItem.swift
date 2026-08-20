import SwiftUI

struct HomeInfoItem: View {
    let title: String
    let value: String
    let systemImage: String
    let primaryText: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(primaryText)
                .frame(width: 54, height: 54)
                .background(Color.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(primaryText)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(primaryText)
            }
        }
    }
}

#Preview {
    HomeInfoItem(
        title: "Active Hydrophones",
        value: "2/6",
        systemImage: "waveform",
        primaryText: .primary
    )
    .padding()
}
