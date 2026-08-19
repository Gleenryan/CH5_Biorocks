import SwiftUI
import SwiftData
import Charts
import CoreLocation

struct SiteOverviewView: View {
    let site: Site
    let hydrophones: [CustomLocation]

    @EnvironmentObject private var store: DetectionStore
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse) private var events: [BlastDetectionEvent]
    @Query(sort: \HealthSnapshotRecord.windowStart, order: .reverse) private var snapshots: [HealthSnapshotRecord]

    private var siteEvents: [BlastDetectionEvent] {
        events.filter { $0.siteName == site.name }
    }

    private var siteHealth: [HealthSnapshotRecord] {
        snapshots.filter { $0.siteName == site.name }
    }

    private var liveCount: Int {
        store.liveHydrophones.filter { $0.siteName == site.name && $0.connected }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            mapAndSummary
            metricsGrid
            activityAndTrend
        }
    }

    private var mapAndSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                mapCard.frame(minWidth: 330, maxWidth: .infinity)
                summaryCard.frame(width: 218)
            }
            VStack(spacing: 16) {
                mapCard
                summaryCard
            }
        }
    }

    private var mapCard: some View {
        SiteMapView(site: site)
            .frame(minHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(8)
            .siteGlassCard(cornerRadius: 18)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Site Summary")
                .font(.headline)

            OverviewSummaryRow(
                title: "Sensors live",
                value: "\(liveCount) / \(hydrophones.count)",
                systemImage: "sensor"
            )
            OverviewSummaryRow(
                title: "Last update",
                value: lastUpdateText,
                systemImage: "clock"
            )
            OverviewSummaryRow(
                title: "Blast alerts",
                value: "\(siteEvents.count)",
                systemImage: "bell"
            )
            OverviewSummaryRow(
                title: "Route length",
                value: routeLength,
                systemImage: "point.topleft.down.to.point.bottomright.curvepath"
            )
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 316, alignment: .topLeading)
        .siteGlassCard(cornerRadius: 18)
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            MetricCard(
                title: "Health composite",
                value: siteHealth.first.map { String(format: "%.0f", $0.healthScore) } ?? "—",
                change: siteHealth.first?.healthClass ?? "awaiting audio",
                tint: .accentColor,
                points: siteHealth.prefix(8).reversed().map(\.healthScore)
            )
            MetricCard(
                title: "NDSI",
                value: siteHealth.first.map { String(format: "%.2f", $0.ndsi) } ?? "—",
                change: "bio vs anthro band",
                tint: .blue,
                points: siteHealth.prefix(8).reversed().map(\.ndsi)
            )
            MetricCard(
                title: "Snap rate",
                value: siteHealth.first.map { String(format: "%.0f /min", $0.snapRatePerMin) } ?? "—",
                change: "2–8 kHz peaks",
                tint: .green,
                points: siteHealth.prefix(8).reversed().map(\.snapRatePerMin)
            )
            MetricCard(
                title: "Low-freq level",
                value: siteHealth.first.map { String(format: "%.1f dBFS", $0.lowFreqSPL_dB) } ?? "—",
                change: "uncalibrated",
                tint: .orange,
                points: siteHealth.prefix(8).reversed().map(\.lowFreqSPL_dB)
            )
        }
    }

    private var activityAndTrend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                recentAlertsCard.frame(minWidth: 290, maxWidth: .infinity)
                healthTrendCard.frame(minWidth: 320, maxWidth: .infinity)
            }
            VStack(spacing: 16) {
                recentAlertsCard
                healthTrendCard
            }
        }
    }

    private var recentAlertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Alerts")
                .font(.headline)

            if siteEvents.isEmpty {
                Text("No promoted blast events for this Site yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(siteEvents.prefix(3)) { event in
                    AlertRow(
                        title: event.narrative.split(separator: "\n").first.map(String.init) ?? "Blast detection",
                        detail: "\(event.hydrophoneName) · \(event.onsetTime.formatted(date: .omitted, time: .shortened))",
                        severity: event.severity,
                        systemImage: "waveform.path",
                        tint: event.severity.lowercased() == "high" ? .red : .orange
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .siteGlassCard(cornerRadius: 18)
    }

    private var healthTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Health composite")
                    .font(.headline)
                Spacer()
                Text("Unsupervised")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if siteHealth.count < 2 {
                Text("A trend appears after two or more hydrophone snapshots.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                Chart(Array(siteHealth.prefix(12).reversed()), id: \.id) { snap in
                    LineMark(
                        x: .value("Time", snap.windowStart),
                        y: .value("Score", snap.healthScore)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .chartYScale(domain: 0 ... 100)
                .frame(minHeight: 210)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .siteGlassCard(cornerRadius: 18)
    }

    private var lastUpdateText: String {
        let eventDate = siteEvents.first?.onsetTime
        let healthDate = siteHealth.first?.windowStart
        guard let latest = [eventDate, healthDate].compactMap({ $0 }).max() else {
            return liveCount > 0 ? "live" : "never"
        }
        return latest.formatted(.relative(presentation: .named))
    }

    private var routeLength: String {
        let start = CLLocation(latitude: site.startLatitude, longitude: site.startLongitude)
        let end = CLLocation(latitude: site.endLatitude, longitude: site.endLongitude)
        let meters = start.distance(from: end)
        if meters >= 1_000 {
            return "\((meters / 1_000).formatted(.number.precision(.fractionLength(1)))) km"
        }
        return "\(meters.formatted(.number.precision(.fractionLength(0)))) m"
    }
}

private struct OverviewSummaryRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let change: String
    let tint: Color
    let points: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(value)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(change)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }

            if points.count > 1 {
                Chart(Array(points.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Sample", index),
                        y: .value(title, value)
                    )
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 34)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .siteGlassCard(cornerRadius: 16)
    }
}

private struct AlertRow: View {
    let title: String
    let detail: String
    let severity: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(severity)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(tint.opacity(0.1), in: Capsule())
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 12))
    }
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
        hydrophones: []
    )
    .environmentObject(DetectionStore())
    .environmentObject(HydrophoneHub())
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 900, height: 900)
    .padding()
}
