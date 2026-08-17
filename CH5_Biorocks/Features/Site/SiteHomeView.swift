import SwiftUI
import SwiftData

struct SiteHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Site.createdAt, order: .reverse) private var sites: [Site]

    @State private var isPresentingNewSite = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 24) {
                    Spacer(minLength: 35)

                    VStack(spacing: 12) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 78, height: 78)
                            .background(.white.opacity(0.18), in: Circle())
                            .overlay { Circle().stroke(.white.opacity(0.55), lineWidth: 1) }

                        Text("BIOROCKS")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white)
                    }

                    sitePanel

                    Spacer(minLength: 55)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                if isPresentingNewSite {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { dismissNewSite() }

                    SiteFormOverlay(
                        onCancel: dismissNewSite,
                        onSubmit: createSite
                    )
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: isPresentingNewSite)
        }
        .frame(minWidth: 540, minHeight: 520)
    }

    private var background: some View {
        Image("OnBoardingBackground")
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
    }

    private var sitePanel: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT SITES")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))

                if sites.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 24))
                        Text("No Sites yet")
                            .font(.headline)
                        Text("Create your first monitoring Site to get started.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(sites) { site in
                                NavigationLink {
                                    SiteDetailView(site: site)
                                } label: {
                                    SiteRow(site: site)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete Site", role: .destructive) {
                                        modelContext.delete(site)
                                    }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(24)
            .frame(minWidth: 270, idealWidth: 330, maxWidth: 330, minHeight: 260, maxHeight: 260)

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(width: 1, height: 230)

            VStack(spacing: 16) {
                Text("CREATE NEW SITE")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))

                Button {
                    isPresentingNewSite = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 70)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "1DB7D9"), Color(hex: "29CBB5")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 15)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.white.opacity(0.8), lineWidth: 3)
                                .padding(5)
                        }
                }
                .buttonStyle(.plain)
                .help("Create a new Site")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: 650, minHeight: 260, maxHeight: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 28, y: 15)
    }

    private func createSite(
        name: String,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double
    ) {
        let site = Site(
            name: name,
            startLatitude: startLatitude,
            startLongitude: startLongitude,
            endLatitude: endLatitude,
            endLongitude: endLongitude
        )
        modelContext.insert(site)
        dismissNewSite()
    }

    private func dismissNewSite() {
        isPresentingNewSite = false
    }
}

private struct SiteRow: View {
    let site: Site

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "water.waves.and.arrow.trianglehead.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("\(site.hydrophones.count) hydrophone\(site.hydrophones.count == 1 ? "" : "s")")
                    .font(.caption)
                    .opacity(0.78)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(
            LinearGradient(
                colors: [Color(hex: "1DB7D9"), Color(hex: "29CBB5")],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }
}

#Preview {
    SiteHomeView()
        .modelContainer(for: [Site.self, CustomLocation.self], inMemory: true)
}
