import SwiftUI
import SwiftData

struct SiteDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let site: Site

    @State private var selectedTab: SiteDetailTab = .overview
    @State private var isPresentingHydrophone = false
    @State private var editingHydrophone: CustomLocation?
    @State private var hydrophoneMapRefreshID = UUID()

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
                    defaultCoordinate: site.coverageCenterCoordinate,
                    siteCoverageCenter: site.coverageCenterCoordinate,
                    siteCoverageRadiusMeters: site.coverageRadiusMeters,
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
                            title: "Finish",
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
                            title: "Finish",
                            latitude: site.endLatitude,
                            longitude: site.endLongitude
                        )
                    }
                }
            }

            Spacer(minLength: 10)

            LiveStatusBadge(siteName: site.name)
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
            AlertsView(siteName: site.name)

        case .coralHealth:
            CoralHealthView(siteName: site.name)
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
                .id(hydrophoneMapRefreshID)
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
                    Text("Add a hydrophone, or run the Python simulator — detected streams appear here automatically.")
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

        hydrophoneMapRefreshID = UUID()
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

    @EnvironmentObject private var store: DetectionStore
    @EnvironmentObject private var hub: HydrophoneHub
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse) private var events: [BlastDetectionEvent]
    @State private var isConfirmingDeletion = false

    private var liveStatus: LiveHydrophoneStatus? {
        store.liveHydrophones.first { status in
            status.simulatorDeviceID == hydrophone.microphoneDeviceID
                || (status.name.localizedCaseInsensitiveCompare(hydrophone.name) == .orderedSame
                    && status.siteName.localizedCaseInsensitiveCompare(hydrophone.site?.name ?? "") == .orderedSame)
        }
    }

    private var isLive: Bool { liveStatus?.connected == true }
    private var hydrophoneAudioID: String? { liveStatus?.id }
    private var isListening: Bool {
        guard let hydrophoneAudioID else { return false }
        return store.listeningHydrophoneID == hydrophoneAudioID
    }

    private var blastEvent: BlastDetectionEvent? {
        let deviceID = hydrophone.microphoneDeviceID ?? ""
        let simID = deviceID.hasPrefix("sim://") ? String(deviceID.dropFirst(6)) : deviceID
        return events.first { event in
            event.hydrophoneId.caseInsensitiveCompare(simID) == .orderedSame
                || event.hydrophoneId.caseInsensitiveCompare(deviceID) == .orderedSame
                || (
                    event.hydrophoneName.localizedCaseInsensitiveCompare(hydrophone.name) == .orderedSame
                        && event.siteName.localizedCaseInsensitiveCompare(hydrophone.site?.name ?? "") == .orderedSame
                )
        }
    }

    private var hasBlast: Bool { blastEvent != nil }

    var body: some View {
        HStack(spacing: 12) {
            waveformOrPlaceholder
                .frame(width: 88, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(hydrophone.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    if hydrophone.microphoneDeviceID?.hasPrefix("sim://") == true {
                        Text(isLive ? "Detected" : "Simulator")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isLive ? Color.green : Color.secondary)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background((isLive ? Color.green : Color.secondary).opacity(0.14), in: Capsule())
                    }

                    if hasBlast {
                        Text("BLAST")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(Color.red.opacity(0.16), in: Capsule())
                    }
                }

                Text("\(hydrophone.latitude.formatted(.number.precision(.fractionLength(4)))), \(hydrophone.longitude.formatted(.number.precision(.fractionLength(4))))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let blastEvent {
                    Text("Blast alert · P \(blastEvent.pBlast.formatted(.number.precision(.fractionLength(3)))) · \(blastEvent.onsetTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                if isLive, let rms = liveStatus?.lastRMS {
                    Text(String(format: "Live audio · rms %.3f", rms))
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                } else if liveStatus != nil, store.hasClip[liveStatus?.id ?? ""] == true {
                    Text("Scenario audio attached")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let microphoneName = hydrophone.microphoneDeviceName {
                    Text(microphoneName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if let hydrophoneAudioID {
                    audioControl(id: hydrophoneAudioID)
                }

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
        .overlay {
            if hasBlast {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(0.55), lineWidth: 1.5)
            } else if isLive {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green.opacity(0.45), lineWidth: 1.5)
            }
        }
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

    @ViewBuilder
    private var waveformOrPlaceholder: some View {
        if let id = hydrophoneAudioID, !store.envelope(for: id).isEmpty {
            LiveWaveformView(samples: store.envelope(for: id), isLive: isLive)
        } else {
            HydrophoneImagePlaceholder()
        }
    }

    @ViewBuilder
    private func audioControl(id: String) -> some View {
        if isLive {
            Button {
                hub.toggleListen(hydrophoneID: id)
            } label: {
                Image(systemName: isListening ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .foregroundStyle(isListening ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(isListening ? "Mute this hydrophone" : "Listen to this hydrophone")
        } else if store.hasClip[id] == true {
            Button {
                hub.replay(hydrophoneID: id)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.plain)
            .help("Replay attached scenario audio")
        }
    }
}

private struct LiveStatusBadge: View {
    let siteName: String
    @EnvironmentObject private var store: DetectionStore

    private var isLive: Bool {
        store.liveHydrophones.contains { $0.siteName == siteName && $0.connected }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Label(isLive ? "Live" : "Idle", systemImage: "circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(isLive ? Color.green : Color.secondary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background((isLive ? Color.green : Color.secondary).opacity(0.12), in: Capsule())

            Text(isLive ? "Hydrophone streaming" : "No live stream")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SiteDetailView(
        site: Site(
            name: "Pemuteran",
            startLatitude: -8.1287,
            startLongitude: 114.6608,
            endLatitude: -8.1322,
            endLongitude: 114.6715
        )
    )
    .environmentObject(DetectionStore())
    .environmentObject(HydrophoneHub())
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 900, height: 760)
    .padding()
}
