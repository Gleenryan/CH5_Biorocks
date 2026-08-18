import SwiftUI
import SwiftData

struct SiteDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let site: Site

    @State private var selectedTab: SiteDetailTab = .overview
    @State private var isPresentingHydrophone = false
    @State private var editingHydrophone: CustomLocation?

    private var sortedHydrophones: [CustomLocation] {
        site.hydrophones.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                siteHeader
                tabPicker
                selectedTabContent
            }
            .padding(4)

            if isPresentingHydrophone {
                Color.black.opacity(0.36)
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismissHydrophoneForm)

                HydrophoneFormCard(
                    initialLocation: editingHydrophone,
                    onCancel: dismissHydrophoneForm,
                    onSubmit: saveHydrophone
                )
                .id(editingHydrophone?.id.uuidString ?? "new-hydrophone")
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .shadow(color: .black.opacity(0.24), radius: 26, y: 12)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPresentingHydrophone)
    }

    private var siteHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            SiteImagePlaceholder()
                .frame(width: 102, height: 88)

            VStack(alignment: .leading, spacing: 8) {
                Text(site.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)

                Text("Reef monitoring Site")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 9) {
                        coordinateChip(
                            title: "Start",
                            latitude: site.startLatitude,
                            longitude: site.startLongitude
                        )
                        coordinateChip(
                            title: "End",
                            latitude: site.endLatitude,
                            longitude: site.endLongitude
                        )
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        coordinateChip(
                            title: "Start",
                            latitude: site.startLatitude,
                            longitude: site.startLongitude
                        )
                        coordinateChip(
                            title: "End",
                            latitude: site.endLatitude,
                            longitude: site.endLongitude
                        )
                    }
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 5) {
                Label("Online", systemImage: "circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.green.opacity(0.12), in: Capsule())

                Text("Demo status")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .help("Online is placeholder data for this prototype")
        }
        .padding(18)
        .siteGlassCard(cornerRadius: 18)
    }

    private var tabPicker: some View {
        Picker("Site Section", selection: $selectedTab) {
            ForEach(SiteDetailTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 620, alignment: .leading)
        .accessibilityLabel("Site section")
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .overview:
            ScrollView {
                SiteOverviewView(site: site, hydrophones: sortedHydrophones)
                    .padding(4)
            }
            .scrollIndicators(.hidden)

        case .sensors:
            ScrollView {
                sensorsContent
                    .padding(4)
            }
            .scrollIndicators(.hidden)

        case .alerts:
            emptyTab(
                title: "No Site Alerts",
                description: "Alert monitoring has not been connected for this Site yet.",
                systemImage: "bell.slash"
            )

        case .coralHealth:
            emptyTab(
                title: "No Coral Health Data",
                description: "Coral health observations will appear here when this feature is connected.",
                systemImage: "waveform.path.ecg"
            )
        }
    }

    private var sensorsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hydrophone Sensors")
                        .font(.title3.bold())

                    Text("Manage microphones and their positions for this Site.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    editingHydrophone = nil
                    isPresentingHydrophone = true
                } label: {
                    Label("Add Hydrophone", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            SiteMapView(site: site)
                .frame(minHeight: 250)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Divider()

            HStack {
                Text("Sensors")
                    .font(.headline)

                Text("\(sortedHydrophones.count)")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())

                Spacer()
            }

            if sortedHydrophones.isEmpty {
                ContentUnavailableView {
                    Label("No Hydrophones", systemImage: "mic.slash")
                } description: {
                    Text("Use Add Hydrophone to connect a microphone and position it on the map.")
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 250), spacing: 12)],
                    spacing: 12
                ) {
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
        }
        .padding(18)
        .siteGlassCard(cornerRadius: 18)
    }

    private func emptyTab(
        title: String,
        description: String,
        systemImage: String
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .siteGlassCard(cornerRadius: 18)
    }

    private func coordinateChip(title: String, latitude: Double, longitude: Double) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .fontWeight(.semibold)
            Text("\(formatted(latitude)), \(formatted(longitude))")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .glassEffect(.regular, in: .capsule)
    }

    private func saveHydrophone(
        name: String,
        latitude: Double,
        longitude: Double,
        microphoneDeviceID: String,
        microphoneDeviceName: String
    ) {
        if let editingHydrophone {
            editingHydrophone.name = name
            editingHydrophone.latitude = latitude
            editingHydrophone.longitude = longitude
            editingHydrophone.microphoneDeviceID = microphoneDeviceID
            editingHydrophone.microphoneDeviceName = microphoneDeviceName
        } else {
            let hydrophone = CustomLocation(
                name: name,
                latitude: latitude,
                longitude: longitude,
                microphoneDeviceID: microphoneDeviceID,
                microphoneDeviceName: microphoneDeviceName,
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
}

private enum SiteDetailTab: String, CaseIterable, Identifiable {
    case overview
    case sensors
    case alerts
    case coralHealth

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .sensors: "Sensors"
        case .alerts: "Alerts"
        case .coralHealth: "Coral Health"
        }
    }
}

private struct HydrophoneRow: View {
    let hydrophone: CustomLocation
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isConfirmingDeletion = false

    var body: some View {
        HStack(spacing: 12) {
            HydrophoneImagePlaceholder()
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(hydrophone.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text("\(hydrophone.latitude.formatted(.number.precision(.fractionLength(4)))), \(hydrophone.longitude.formatted(.number.precision(.fractionLength(4))))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let microphoneName = hydrophone.microphoneDeviceName {
                    Text(microphoneName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Edit Hydrophone")

                Button(role: .destructive) {
                    isConfirmingDeletion = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Delete Hydrophone")
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .siteGlassCard(cornerRadius: 14)
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive) {
                isConfirmingDeletion = true
            }
        }
        .confirmationDialog(
            "Delete \(hydrophone.name)?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Hydrophone", role: .destructive, action: onDelete)
        } message: {
            Text("This hydrophone will be permanently removed from this Site.")
        }
    }
}

#Preview {
    SiteDetailView(
        site: Site(
            name: "Nusa Penida (Demo)",
            startLatitude: -8.7270,
            startLongitude: 115.5440,
            endLatitude: -8.7205,
            endLongitude: 115.5530
        )
    )
    .modelContainer(for: [Site.self, CustomLocation.self], inMemory: true)
    .frame(width: 900, height: 760)
    .padding()
}
