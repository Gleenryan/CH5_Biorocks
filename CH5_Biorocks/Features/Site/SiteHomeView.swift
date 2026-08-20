import SwiftUI
import MapKit
import SwiftData

struct SiteHomeView: View {
    let sites: [Site]
    let onAddSite: () -> Void
    var onViewAllAlerts: () -> Void = {}

    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse)
    private var events: [BlastDetectionEvent]
    @Query(sort: \HealthSnapshotRecord.windowStart, order: .reverse)
    private var snapshots: [HealthSnapshotRecord]
    @Environment(\.colorScheme) private var colorScheme

    private var hydrophoneCount: Int {
        sites.reduce(0) { $0 + $1.hydrophones.count }
    }

    private var primaryText: Color {
        colorScheme == .dark ? .primary : .coralystText
    }

    private var latestSnapshot: HealthSnapshotRecord? {
        snapshots.first
    }

    @MainActor private var recentAlerts: [HomeAlert] {
        let recordedAlerts = events.prefix(3).map(HomeAlert.init(event:))
        return recordedAlerts.isEmpty ? HomeAlert.preview : Array(recordedAlerts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                recentAlertsSection
                sitesSummarySection
                coverageSummary
                siteStatus
            }
            .frame(maxWidth: 1_440, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 30)
        }
        .scrollIndicators(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        Text("All Sites Overview")
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(primaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private var recentAlertsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Alerts")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(primaryText)

                Spacer()
                
                Button(action: onViewAllAlerts) {
                    HStack(spacing: 4) {
                        Text("All Alerts")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundStyle(primaryText)
                }
                .buttonStyle(.plain)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    ForEach(recentAlerts) { alert in
                        HomeAlertCard(alert: alert, primaryText: primaryText)
                            .frame(maxWidth: 400)
                    }
                    Spacer()
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 290), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(recentAlerts) { alert in
                        HomeAlertCard(alert: alert, primaryText: primaryText)
                    }
                }
            }
        }
    }

    private var sitesSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sites Summary")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(primaryText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 180), spacing: 30)],
                spacing: 16
            ) {
                HomeMetricCard(
                    title: "Health Composition",
                    value: latestSnapshot.map { String(format: "%.0f", $0.healthScore) } ?? "80",
                    trend: "+ 2",
                    status: latestSnapshot?.healthClass ?? "Healthy",
                    trendIsPositive: true,
                    primaryText: primaryText
                )
                HomeMetricCard(
                    title: "NDSI",
                    value: latestSnapshot.map { String(format: "%.2f", $0.ndsi) } ?? "0.78",
                    trend: "+ 0.087",
                    status: "Good",
                    trendIsPositive: true,
                    primaryText: primaryText
                )
                HomeMetricCard(
                    title: "Snap Rate / min",
                    value: latestSnapshot.map { String(format: "%.0f", $0.snapRatePerMin) } ?? "53",
                    trend: "− 0.087",
                    status: "Normal",
                    trendIsPositive: false,
                    primaryText: primaryText
                )
                HomeMetricCard(
                    title: "Low Freq dBFS",
                    value: latestSnapshot.map { String(format: "%.1f", $0.lowFreqSPL_dB) } ?? "−54.1",
                    trend: "− 3.3",
                    status: "Normal",
                    trendIsPositive: false,
                    primaryText: primaryText
                )
                HomeMetricCard(
                    title: "Bomb Alerts",
                    value: "\(events.count)",
                    trend: nil,
                    status: events.isEmpty ? "Clear" : "Check needed",
                    trendIsPositive: events.isEmpty,
                    primaryText: primaryText
                )
            }

            Text("*Trend is compared to the last 24 hrs")
                .font(.callout.italic())
                .foregroundStyle(primaryText.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var coverageSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment:.top,spacing: 64) {
                HomeInfoItem(
                    title: "Active Hydrophones",
                    value: "\(hydrophoneCount)/\(max(hydrophoneCount, sites.count * 3))",
                    systemImage: "waveform",
                    primaryText: primaryText
                )
                HomeInfoItem(
                    title: "Depth Range",
                    value: "4 – 15m",
                    systemImage: "water.waves",
                    primaryText: primaryText
                )
                HomeInfoItem(
                    title: "Total Coverage",
                    value: coverageText,
                    systemImage: "circle.circle",
                    primaryText: primaryText
                )
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 210), spacing: 24)],
                spacing: 18
            ) {
                HomeInfoItem(title: "Active Hydrophones", value: "\(hydrophoneCount)/\(max(hydrophoneCount, sites.count * 3))", systemImage: "waveform", primaryText: primaryText)
                HomeInfoItem(title: "Depth Range", value: "4 – 15m", systemImage: "water.waves", primaryText: primaryText)
                HomeInfoItem(title: "Total Coverage", value: coverageText, systemImage: "circle.circle", primaryText: primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var siteStatus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                siteMap
                    .frame(minWidth: 280, idealWidth: 470, maxWidth: 500)

                siteStatusTable
                    .frame(minWidth: 400, maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 20) {
                siteMap
                    .frame(maxWidth: 500, alignment: .leading)
                siteStatusTable
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(primaryText.opacity(colorScheme == .dark ? 0.35 : 0.7), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.10), radius: 8, y: 3)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var siteMap: some View {
        ZStack {
            Map {
                ForEach(sites) { site in
                    MapCircle(center: site.coverageCenterCoordinate, radius: max(site.coverageRadiusMeters, 1))
                        .foregroundStyle(Color.coralystPrimary.opacity(0.12))
                        .stroke(Color.coralystPrimary, lineWidth: 2)

                    Marker(site.name, systemImage: "water.waves", coordinate: site.coverageCenterCoordinate)
                        .tint(Color.coralystPrimary)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls { MapScaleView() }

            if sites.isEmpty {
                ContentUnavailableView {
                    Label("No Sites", systemImage: "map")
                } description: {
                    Text("Add your first Site to display its status.")
                } actions: {
                    Button("Add Site", action: onAddSite)
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .frame(height: 350)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var siteStatusTable: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Site Status")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(primaryText)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 16) {
                GridRow {
                    statusHeading("Site")
                    statusHeading("Health\nComposite")
                    statusHeading("NDSI")
                    statusHeading("Snap Rate")
                    statusHeading("Bomb Alerts")
                }

                Divider().gridCellColumns(5)

                ForEach(sites) { site in
                    GridRow {
                        Text(site.name).lineLimit(1)
                        Text(healthValue(for: site))
                        Text(ndsiValue(for: site))
                        Text(snapRateValue(for: site))
                        Text("\(events.filter { $0.siteName == site.name }.count)")
                    }
                    .font(.title3)
//                    .fontWeight(.semibold)
                    .foregroundStyle(primaryText)
                }
            }

            if sites.isEmpty {
                Text("Create a Site to see its real monitoring status here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.trailing, 12)
    }

    private var coverageText: String {
        let squareMeters = sites.reduce(0.0) { total, site in
            total + .pi * pow(site.coverageRadiusMeters, 2)
        }
        guard squareMeters > 0 else { return "—" }
        return "\((squareMeters / 1_000_000).formatted(.number.precision(.fractionLength(1)))) km²"
    }

    private func healthValue(for site: Site) -> String {
        guard let snapshot = snapshots.first(where: { $0.siteName == site.name }) else { return "—" }
        return String(format: "%.0f", snapshot.healthScore)
    }

    private func ndsiValue(for site: Site) -> String {
        guard let snapshot = snapshots.first(where: { $0.siteName == site.name }) else { return "—" }
        return String(format: "%.2f", snapshot.ndsi)
    }

    private func snapRateValue(for site: Site) -> String {
        guard let snapshot = snapshots.first(where: { $0.siteName == site.name }) else { return "—" }
        return String(format: "%.0f", snapshot.snapRatePerMin)
    }

    private func statusHeading(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SiteHomeView(
        sites: [
            Site(name: "Amed 1", startLatitude: -8.3405, startLongitude: 115.6582, endLatitude: -8.3385, endLongitude: 115.6612),
            Site(name: "Pemuteran 1", startLatitude: -8.1287, startLongitude: 114.6608, endLatitude: -8.1322, endLongitude: 114.6715)
        ],
        onAddSite: {}
    )
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 1000, height: 720)
}

