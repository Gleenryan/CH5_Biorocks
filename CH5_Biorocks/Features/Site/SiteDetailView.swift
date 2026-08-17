import SwiftUI
import SwiftData

struct SiteDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let site: Site

    @State private var isPresentingHydrophone = false
    @State private var editingHydrophone: CustomLocation?

    private var sortedHydrophones: [CustomLocation] {
        site.hydrophones.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        ZStack {
            Image("OnBoardingBackground")
                .resizable()
                .scaledToFill()
                .overlay { Color.black.opacity(0.18) }
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                hydrophoneHeader

                Rectangle()
                    .fill(.white.opacity(0.45))
                    .frame(height: 1)

                GeometryReader { proxy in
                    ScrollView {
                        ViewThatFits(in: .horizontal) {
                            horizontalDetailCard
                            verticalDetailCard
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, horizontalPadding(for: proxy.size.width))
                        .padding(.vertical, 32)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            if isPresentingHydrophone {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .onTapGesture { dismissHydrophoneForm() }

                HydrophoneFormCard(
                    initialLocation: editingHydrophone,
                    onCancel: dismissHydrophoneForm,
                    onSubmit: saveHydrophone
                )
                .id(editingHydrophone?.id.uuidString ?? "new-hydrophone")
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .shadow(color: .black.opacity(0.3), radius: 35, y: 18)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPresentingHydrophone)
    }

    private var hydrophoneHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(hex: "17467D"))
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.9), in: Circle())

            Text("HYDROPHONE LIST")
                .font(.system(size: 42, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 48)
        .padding(.top, 72)
        .padding(.bottom, 24)
    }

    private var horizontalDetailCard: some View {
        HStack(spacing: 0) {
            mapPanel
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(width: 1)

            siteInformationPanel
                .frame(minWidth: 280, idealWidth: 360, maxWidth: 420, maxHeight: .infinity)
        }
        .frame(minHeight: 460)
        .siteDetailCardStyle()
    }

    private var verticalDetailCard: some View {
        VStack(spacing: 0) {
            mapPanel
                .frame(height: 300)

            Divider()

            siteInformationPanel
                .frame(minHeight: 340)
        }
        .siteDetailCardStyle()
    }

    private var mapPanel: some View {
        SiteMapView(site: site)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.1), lineWidth: 1)
            }
            .padding(18)
    }

    private var siteInformationPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(site.name.uppercased())
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .lineLimit(2)

                    Text("Start: \(formatted(site.startLatitude)), \(formatted(site.startLongitude))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("End: \(formatted(site.endLatitude)), \(formatted(site.endLongitude))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)

                Spacer()

                Button {
                    editingHydrophone = nil
                    isPresentingHydrophone = true
                } label: {
                    Label("Add Hydrophone", systemImage: "plus")
                }
                .buttonStyle(SitePrimaryButtonStyle())
                .help("Add Hydrophone")
            }

            Divider()

            HStack {
                Text("HYDROPHONES")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Text("\(sortedHydrophones.count) installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sortedHydrophones.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "mic.slash")
                        .font(.system(size: 30))
                    Text("No hydrophones in this Site")
                        .font(.headline)
                    Text("Add a hydrophone to display it on the map.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(sortedHydrophones) { hydrophone in
                            HydrophoneRow(
                                hydrophone: hydrophone,
                                onEdit: {
                                    editingHydrophone = hydrophone
                                    isPresentingHydrophone = true
                                },
                                onDelete: {
                                    modelContext.delete(hydrophone)
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity)
    }

    private func saveHydrophone(name: String, latitude: Double, longitude: Double) {
        if let editingHydrophone {
            editingHydrophone.name = name
            editingHydrophone.latitude = latitude
            editingHydrophone.longitude = longitude
        } else {
            let hydrophone = CustomLocation(
                name: name,
                latitude: latitude,
                longitude: longitude,
                site: site
            )
            modelContext.insert(hydrophone)
        }

        dismissHydrophoneForm()
    }

    private func dismissHydrophoneForm() {
        isPresentingHydrophone = false
        editingHydrophone = nil
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(4)))
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        min(max(32, width * 0.04), 64)
    }

}

private extension View {
    func siteDetailCardStyle() -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.58), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

private struct HydrophoneRow: View {
    let hydrophone: CustomLocation
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "mic.fill")
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color(hex: "17C3B2"), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(hydrophone.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("\(hydrophone.latitude.formatted(.number.precision(.fractionLength(4)))), \(hydrophone.longitude.formatted(.number.precision(.fractionLength(4))))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit Hydrophone")
        }
        .padding(.horizontal, 11)
        .frame(height: 56)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

#Preview {
    SiteDetailView(
        site: Site(
            name: "Pemuteran Reef",
            startLatitude: -8.1287,
            startLongitude: 114.6608,
            endLatitude: -8.1402,
            endLongitude: 114.6721
        )
    )
    .modelContainer(for: [Site.self, CustomLocation.self], inMemory: true)
    .frame(width: 1000, height: 700)
}
