import Foundation
import SwiftUI
import SwiftData

struct SiteOverviewView: View {
    let site: Site
    let hydrophones: [CustomLocation]
    let onViewSensors: () -> Void
    let onViewAlerts: () -> Void
    let onSelectHydrophone: (CustomLocation) -> Void
    let onSelectAlert: (BlastDetectionEvent) -> Void

    @EnvironmentObject private var store: DetectionStore
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse) private var events: [BlastDetectionEvent]
    @Query(sort: \HealthSnapshotRecord.windowStart, order: .reverse) private var snapshots: [HealthSnapshotRecord]

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(hex: "0F172A")
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

    private var recentEvents: [BlastDetectionEvent] {
        Array(siteEvents.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            recentAlertsSection
            siteSummarySection
            hydrophoneFleetSection
        }
    }

    // MARK: - 1. Recent Alerts Section
    private var recentAlertsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "EF4444"))

                    Text("Recent Alerts")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(primaryText)

                    if !siteEvents.isEmpty {
                        Text("\(siteEvents.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(Color(hex: "EF4444"), in: Capsule())
                    }
                }

                Spacer()

                Button(action: onViewAlerts) {
                    HStack(spacing: 5) {
                        Text("All Alerts")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.coralystPrimary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    recentAlertCards
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300), spacing: 20)],
                    spacing: 20
                ) {
                    recentAlertCards
                }
            }
        }
    }

    @ViewBuilder
    private var recentAlertCards: some View {
        if recentEvents.isEmpty {
            ForEach(AlertSummary.preview.prefix(3)) { alert in
                AlertCard(alert: alert, primaryText: primaryText)
            }
        } else {
            ForEach(recentEvents) { event in
                Button {
                    onSelectAlert(event)
                } label: {
                    AlertCard(alert: AlertSummary(event: event), primaryText: primaryText)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Open alert details")
            }
        }
    }

    // MARK: - 2. Site Summary & Telemetry
    private var siteSummarySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)

                Text("Site Summary & Telemetry")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryText)
            }

            // 5 Metric Cards
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    metricCards
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 175), spacing: 18)],
                    spacing: 18
                ) {
                    metricCards
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                Text("Trend compares the two latest available telemetry windows")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        let healthTrend = trend(for: \.healthScore, fractionDigits: 0)
        let ndsiTrend = trend(for: \.ndsi, fractionDigits: 2)
        let snapRateTrend = trend(for: \.snapRatePerMin, fractionDigits: 0)
        let lowFrequencyTrend = trend(for: \.lowFreqSPL_dB, fractionDigits: 1, lowerIsBetter: true)

        MetricCard(
            title: "Health Composition",
            value: latestSnapshot.map { String(format: "%.0f", $0.healthScore) } ?? "—",
            trend: healthTrend.text,
            status: latestSnapshot?.healthClass ?? "Awaiting data",
            trendIsPositive: healthTrend.isPositive,
            primaryText: primaryText
        )
        MetricCard(
            title: "NDSI",
            value: latestSnapshot.map { String(format: "%.2f", $0.ndsi) } ?? "—",
            trend: ndsiTrend.text,
            status: latestSnapshot == nil ? "Awaiting data" : "Good",
            trendIsPositive: ndsiTrend.isPositive,
            primaryText: primaryText
        )
        MetricCard(
            title: "Snap Rate / min",
            value: latestSnapshot.map { String(format: "%.0f", $0.snapRatePerMin) } ?? "—",
            trend: snapRateTrend.text,
            status: latestSnapshot == nil ? "Awaiting data" : "Normal",
            trendIsPositive: snapRateTrend.isPositive,
            primaryText: primaryText
        )
        MetricCard(
            title: "Low Freq dBFS",
            value: latestSnapshot.map { String(format: "%.1f", $0.lowFreqSPL_dB) } ?? "—",
            trend: lowFrequencyTrend.text,
            status: latestSnapshot == nil ? "Awaiting data" : "Normal",
            trendIsPositive: lowFrequencyTrend.isPositive,
            primaryText: primaryText
        )
        MetricCard(
            title: "Bomb Alerts",
            value: "\(siteEvents.count)",
            trend: nil,
            status: siteEvents.isEmpty ? "Clear" : "Check needed",
            trendIsPositive: siteEvents.isEmpty,
            primaryText: primaryText
        )
    }

    // MARK: - 3. Hydrophone Fleet Section
    private var hydrophoneFleetSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "mic.badge.waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)

                Text("Hydrophone Fleet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryText)

                Text("\(hydrophones.count)")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color.coralystPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.coralystPrimary.opacity(0.12), in: Capsule())
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    compactSquareMap
                        .frame(width: 380, height: 360)

                    hydrophoneGridCard
                        .frame(minWidth: 480, maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 24) {
                    compactSquareMap
                        .frame(width: 380, height: 340)

                    hydrophoneGridCard
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Compact Square Map Component
    private var compactSquareMap: some View {
        ZStack(alignment: .topLeading) {
            SiteMapView(site: site)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // Floating Array Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
                Text("\(hydrophones.count) Positioned")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(primaryText)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, y: 3)
    }

    // MARK: - Hydrophone Fleet Table Card
    private var hydrophoneGridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hydrophones.isEmpty {
                ContentUnavailableView {
                    Label("No Hydrophones Registered", systemImage: "mic.slash")
                } description: {
                    Text("Add a hydrophone to begin monitoring telemetry for this site.")
                } actions: {
                    Button("Add Hydrophone", action: onViewSensors)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.coralystPrimary)
                }
                .padding(36)
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
                    GridRow {
                        tableHeader("HYDROPHONE")
                        tableHeader("STATUS / LAST SEEN")
                        tableHeader("HEALTH")
                        tableHeader("NDSI")
                        tableHeader("SNAP RATE")
                        tableHeader("ACTION")
                    }

                    Divider()
                        .gridCellColumns(6)
                        .padding(.vertical, 4)

                    ForEach(hydrophones) { hydrophone in
                        let isLive = store.liveHydrophones.contains { $0.name == hydrophone.name && $0.connected }
                        let health = healthValue(for: hydrophone)

                        GridRow {
                            // Hydrophone Name with Icon
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.coralystPrimary.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.coralystPrimary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hydrophone.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(primaryText)

                                    Text("\(hydrophone.latitude.formatted(.number.precision(.fractionLength(3)))), \(hydrophone.longitude.formatted(.number.precision(.fractionLength(3))))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Last Update & Live Status
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isLive ? Color(hex: "10B981") : Color(hex: "94A3B8"))
                                    .frame(width: 7, height: 7)
                                Text(isLive ? "Live Streaming" : lastUpdateText(for: hydrophone))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isLive ? Color(hex: "10B981") : .secondary)
                            }

                            // Health Score
                            HStack(spacing: 4) {
                                Text(health)
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(health == "—" ? .secondary : Color(hex: "10B981"))
                            }

                            // NDSI
                            Text(ndsiValue(for: hydrophone))
                                .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(primaryText)

                            // Snap Rate
                            Text(snapRateValue(for: hydrophone))
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundStyle(primaryText)

                            // Action Inspect Button
                            Button {
                                onSelectHydrophone(hydrophone)
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Inspect")
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.coralystPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.coralystPrimary.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Inspect hydrophone telemetry")
                        }
                        .padding(.vertical, 7)

                        Divider()
                            .gridCellColumns(6)
                            .opacity(0.35)
                    }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, y: 3)
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
        return String(format: "%.0f/m", snapshot.snapRatePerMin)
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
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
        onSelectHydrophone: { _ in },
        onSelectAlert: { _ in }
    )
    .environmentObject(DetectionStore())
    .environmentObject(HydrophoneHub())
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 1_200, height: 900)
    .padding()
}
