import SwiftUI

struct SiteImagePlaceholder: View {
    var showsLabel = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.24),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: showsLabel ? 24 : 18, weight: .medium))

                if showsLabel {
                    Text("Site image")
                        .font(.caption)
                }
            }
            .foregroundStyle(Color.accentColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
        .accessibilityLabel("Site image placeholder")
    }
}

struct HydrophoneImagePlaceholder: View {
    var showsLabel = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.2),
                    Color.accentColor.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 5) {
                Image(systemName: "mic.and.signal.meter")
                    .font(.system(size: showsLabel ? 22 : 18, weight: .medium))

                if showsLabel {
                    Text("Hydrophone image")
                        .font(.caption2)
                }
            }
            .foregroundStyle(Color.accentColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
        .accessibilityLabel("Hydrophone image placeholder")
    }
}

extension View {
    func siteGlassCard(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        glassEffect(
            .regular.interactive(interactive),
            in: .rect(cornerRadius: cornerRadius)
        )
    }
}

#Preview {
    HStack {
        SiteImagePlaceholder()
            .frame(width: 130, height: 100)

        SiteImagePlaceholder(showsLabel: false)
            .frame(width: 64, height: 64)

        HydrophoneImagePlaceholder(showsLabel: true)
            .frame(width: 130, height: 100)
    }
    .padding(40)
    .background(Color(nsColor: .windowBackgroundColor))
}
