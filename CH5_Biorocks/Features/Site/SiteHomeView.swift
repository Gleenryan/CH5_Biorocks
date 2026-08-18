import SwiftUI
import MapKit
import SwiftData

struct SiteHomeView: View {
    let sites: [Site]
    let onAddSite: () -> Void

    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse)
    private var events: [BlastDetectionEvent]

    private var hydrophoneCount: Int {
        sites.reduce(0) { $0 + $1.hydrophones.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                overviewMap
                summaryCards
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .scrollIndicators(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Overview")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Monitor your reef Sites and their installed hydrophones.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var overviewMap: some View {
        ZStack {
            Map {
                ForEach(sites) { site in
                    Marker(
                        site.name,
                        systemImage: "water.waves",
                        coordinate: site.startCoordinate
                    )
                    .tint(Color.accentColor)

                    MapPolyline(coordinates: [site.startCoordinate, site.endCoordinate])
                        .stroke(
                            Color.accentColor.opacity(0.8),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }

            if sites.isEmpty {
                ContentUnavailableView {
                    Label("No Sites", systemImage: "map")
                } description: {
                    Text("Add your first Site from the sidebar to display it on the map.")
                } actions: {
                    Button("Add Site", action: onAddSite)
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(minHeight: 390)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    private var summaryCards: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                SummaryCard(
                    title: "Sites",
                    value: sites.count,
                    systemImage: "folder",
                    detail: sites.count == 1 ? "monitored location" : "monitored locations"
                )

                SummaryCard(
                    title: "Hydrophones",
                    value: hydrophoneCount,
                    systemImage: "mic",
                    detail: hydrophoneCount == 1 ? "installed input" : "installed inputs"
                )

                SummaryCard(
                    title: "Alerts",
                    value: events.count,
                    systemImage: "bell",
                    detail: events.count == 1 ? "promoted detection" : "promoted detections"
                )
            }

            VStack(spacing: 16) {
                SummaryCard(
                    title: "Sites",
                    value: sites.count,
                    systemImage: "folder",
                    detail: sites.count == 1 ? "monitored location" : "monitored locations"
                )

                SummaryCard(
                    title: "Hydrophones",
                    value: hydrophoneCount,
                    systemImage: "mic",
                    detail: hydrophoneCount == 1 ? "installed input" : "installed inputs"
                )

                SummaryCard(
                    title: "Alerts",
                    value: events.count,
                    systemImage: "bell",
                    detail: events.count == 1 ? "promoted detection" : "promoted detections"
                )
            }
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: Int
    let systemImage: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text("\(value) \(detail)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}

#Preview {
    SiteHomeView(
        sites: [
            Site(
                name: "Pemuteran",
                startLatitude: -8.1287,
                startLongitude: 114.6608,
                endLatitude: -8.1322,
                endLongitude: 114.6715
            )
        ],
        onAddSite: {}
    )
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 1000, height: 720)
}
