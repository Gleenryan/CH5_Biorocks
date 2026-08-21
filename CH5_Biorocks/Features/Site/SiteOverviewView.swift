import Foundation
import SwiftUI
import SwiftData

struct SiteOverviewView: View {
    let site: Site
    let hydrophones: [CustomLocation]
    let onViewSensors: () -> Void
    let onViewAlerts: () -> Void
    let onSelectHydrophone: (CustomLocation) -> Void

    @EnvironmentObject private var store: DetectionStore
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse) private var events: [BlastDetectionEvent]
    @Query(sort: \HealthSnapshotRecord.windowStart, order: .reverse) private var snapshots: [HealthSnapshotRecord]

    private var primaryText: Color {
        colorScheme == .dark ? .primary : .coralystText
    }

    private var siteEvents: [BlastDetectionEvent] {
        events.filter { $0.siteName == site.name }
    }

    private var siteHealth: [HealthSnapshotRecord] {
        snapshots.filter { $0.siteName == site.name }
    }

    private var latestSnapshot: HealthSnapshotRecord? {
        siteHealth.first
    }

    private var liveCount: Int {
        store.liveHydrophones.filter { $0.siteName == site.name && $0.connected }.count
    }

    @MainActor private var recentAlerts: [HomeAlert] {
        let alerts = siteEvents.prefix(4).map(HomeAlert.init(event:))
        return alerts.isEmpty ? Array(HomeAlert.preview.prefix(4)) : Array(alerts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            alertsAndMap
            summaryMetrics
            informationSummary
            hydrophoneList
        }
    }

    private var alertsAndMap: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                alertsPanel
                    .frame(minWidth: 520, maxWidth: .infinity)
                overviewMap
                    .frame(minWidth: 520, maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 20) {
                alertsPanel
                overviewMap
            }
        }
    }

    private var alertsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Alerts")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(primaryText)

                Spacer()

                Button(action: onViewAlerts) {
                    Label("More Alerts", systemImage: "chevron.right")
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(primaryText)
            }

            ViewThatFits(in: .horizontal) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(recentAlerts) { alert in
                        HomeAlertCard(alert: alert, primaryText: primaryText)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(recentAlerts) { alert in
                        HomeAlertCard(alert: alert, primaryText: primaryText)
                    }
                }
            }
        }
    }

    private var overviewMap: some View {
        SiteMapView(site: site)
            .frame(minHeight: 370)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(primaryText.opacity(colorScheme == .dark ? 0.35 : 0.75), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.10), radius: 7, y: 3)
    }

    private var summaryMetrics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Site Summary")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(primaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    metricCards
                }
                .frame(maxWidth: .infinity, alignment: .center)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180, maximum: 180), spacing: 18)],
                    spacing: 16
                ) {
                    metricCards
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Text("*Trend compares the two latest available readings")
                .font(.callout.italic())
                .foregroundStyle(primaryText.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        let healthTrend = trend(for: \.healthScore, fractionDigits: 0)
        let ndsiTrend = trend(for: \.ndsi, fractionDigits: 2)
        let snapRateTrend = trend(for: \.snapRatePerMin, fractionDigits: 0)
        let lowFrequencyTrend = trend(for: \.lowFreqSPL_dB, fractionDigits: 1, lowerIsBetter: true)

        HomeMetricCard(
            title: "Health Composition",
            value: latestSnapshot.map { String(format: "%.0f", $0.healthScore) } ?? "—",
            trend: healthTrend.text,
            status: latestSnapshot?.healthClass ?? "Awaiting data",
            trendIsPositive: healthTrend.isPositive,
            primaryText: primaryText
        )
        HomeMetricCard(
            title: "NDSI",
            value: latestSnapshot.map { String(format: "%.2f", $0.ndsi) } ?? "—",
            trend: ndsiTrend.text,
            status: latestSnapshot == nil ? "Awaiting data" : "Good",
            trendIsPositive: ndsiTrend.isPositive,
            primaryText: primaryText
        )
        HomeMetricCard(
            title: "Snap Rate / min",
            value: latestSnapshot.map { String(format: "%.0f", $0.snapRatePerMin) } ?? "—",
            trend: snapRateTrend.text,
            status: latestSnapshot == nil ? "Awaiting data" : "Normal",
            trendIsPositive: snapRateTrend.isPositive,
            primaryText: primaryText
        )
        HomeMetricCard(
            title: "Low Freq dBFS",
            value: latestSnapshot.map { String(format: "%.1f", $0.lowFreqSPL_dB) } ?? "—",
            trend: lowFrequencyTrend.text,
            status: latestSnapshot == nil ? "Awaiting data" : "Normal",
            trendIsPositive: lowFrequencyTrend.isPositive,
            primaryText: primaryText
        )
        HomeMetricCard(
            title: "Bomb Alerts",
            value: "\(siteEvents.count)",
            trend: nil,
            status: siteEvents.isEmpty ? "Clear" : "Check needed",
            trendIsPositive: siteEvents.isEmpty,
            primaryText: primaryText
        )
    }

    private var informationSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 64) {
                HomeInfoItem(
                    title: "Active Hydrophones",
                    value: "\(liveCount)/\(hydrophones.count)",
                    systemImage: "waveform",
                    primaryText: primaryText
                )
                HomeInfoItem(
                    title: "Depth Range",
                    value: "Not recorded",
                    systemImage: "water.waves",
                    primaryText: primaryText
                )
                HomeInfoItem(
                    title: "Coverage Area",
                    value: coverageAreaText,
                    systemImage: "circle.circle",
                    primaryText: primaryText
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 210), spacing: 24)],
                spacing: 18
            ) {
                HomeInfoItem(title: "Active Hydrophones", value: "\(liveCount)/\(hydrophones.count)", systemImage: "waveform", primaryText: primaryText)
                HomeInfoItem(title: "Depth Range", value: "Not recorded", systemImage: "water.waves", primaryText: primaryText)
                HomeInfoItem(title: "Coverage Area", value: coverageAreaText, systemImage: "circle.circle", primaryText: primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var hydrophoneList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hydrophone List")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(primaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            if hydrophones.isEmpty {
                ContentUnavailableView {
                    Label("No Hydrophones", systemImage: "mic.slash")
                } description: {
                    Text("Add a hydrophone from Sensors to begin monitoring this Site.")
                } actions: {
                    Button("Open Sensors", action: onViewSensors)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ViewThatFits(in: .horizontal) {
                    hydrophoneGrid
                    hydrophoneCompactList
                }
            }
        }
        .padding(.bottom, 12)
    }

    private var hydrophoneGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 16) {
            GridRow {
                tableHeading("Hydrophone")
                tableHeading("Last Update")
                tableHeading("Health\nComposition")
                tableHeading("NDSI")
                tableHeading("Snap Rate")
                Color.clear.frame(width: 14)
            }

            Divider().gridCellColumns(6)

            ForEach(hydrophones) { hydrophone in
                GridRow {
                    Text(hydrophone.name).lineLimit(1)
                    Text(lastUpdateText(for: hydrophone)).lineLimit(1)
                    Text(healthValue(for: hydrophone)).lineLimit(1)
                    Text(ndsiValue(for: hydrophone)).lineLimit(1)
                    Text(snapRateValue(for: hydrophone)).lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(primaryText)
                }
                .font(.title3)
                .foregroundStyle(primaryText)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectHydrophone(hydrophone)
                }
                .help("Open hydrophone details")
            }
        }
        .frame(minWidth: 760, alignment: .leading)
    }

    private var hydrophoneCompactList: some View {
        VStack(spacing: 10) {
            ForEach(hydrophones) { hydrophone in
                Button {
                    onSelectHydrophone(hydrophone)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(primaryText)
                            .frame(width: 30, height: 30)
                            .background(Color.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hydrophone.name)
                                .font(.headline)
                            Text("\(lastUpdateText(for: hydrophone)) · NDSI \(ndsiValue(for: hydrophone)) · Snap \(snapRateValue(for: hydrophone))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(primaryText)
                    }
                    .foregroundStyle(primaryText)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var coverageAreaText: String {
        let area = Double.pi * pow(site.coverageRadiusMeters, 2)
        guard area > 0 else { return "—" }
        if area >= 1_000_000 {
            return "\((area / 1_000_000).formatted(.number.precision(.fractionLength(1)))) km²"
        }
        return "\(area.formatted(.number.precision(.fractionLength(0)))) m²"
    }

    private func trend(
        for keyPath: KeyPath<HealthSnapshotRecord, Double>,
        fractionDigits: Int,
        lowerIsBetter: Bool = false
    ) -> MetricTrend {
        guard siteHealth.count >= 2 else {
            return MetricTrend(text: nil, isPositive: true)
        }

        let change = siteHealth[0][keyPath: keyPath] - siteHealth[1][keyPath: keyPath]
        let directionIsPositive = lowerIsBetter ? change < 0 : change >= 0
        let format = "%.\(fractionDigits)f"
        return MetricTrend(
            text: String(format: format, abs(change)),
            isPositive: directionIsPositive
        )
    }

    private func healthSnapshot(for hydrophone: CustomLocation) -> HealthSnapshotRecord? {
        siteHealth.first {
            $0.hydrophoneName.localizedCaseInsensitiveCompare(hydrophone.name) == .orderedSame
        }
    }

    private func lastUpdateText(for hydrophone: CustomLocation) -> String {
        guard let date = healthSnapshot(for: hydrophone)?.windowStart else { return "No data" }
        return date.formatted(.relative(presentation: .named))
    }

    private func healthValue(for hydrophone: CustomLocation) -> String {
        guard let snapshot = healthSnapshot(for: hydrophone) else { return "—" }
        return String(format: "%.0f", snapshot.healthScore)
    }

    private func ndsiValue(for hydrophone: CustomLocation) -> String {
        guard let snapshot = healthSnapshot(for: hydrophone) else { return "—" }
        return String(format: "%.2f", snapshot.ndsi)
    }

    private func snapRateValue(for hydrophone: CustomLocation) -> String {
        guard let snapshot = healthSnapshot(for: hydrophone) else { return "—" }
        return String(format: "%.0f", snapshot.snapRatePerMin)
    }

    private func tableHeading(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MetricTrend {
    let text: String?
    let isPositive: Bool
}

#Preview {
    SiteOverviewView(
        site: Site(
            name: "Pemuteran",
            startLatitude: -8.1287,
            startLongitude: 114.6608,
            endLatitude: -8.1322,
            endLongitude: 114.6715
        ),
        hydrophones: [],
        onViewSensors: {},
        onViewAlerts: {},
        onSelectHydrophone: { _ in }
    )
    .environmentObject(DetectionStore())
    .environmentObject(HydrophoneHub())
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 1_200, height: 900)
    .padding()
}
