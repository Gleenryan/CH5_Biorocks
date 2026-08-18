import SwiftUI
import Charts
import CoreLocation

/// Prototype dashboard content. Monitoring values and alerts are intentionally
/// static until a real sensor/alert data source is connected.
struct SiteOverviewView: View {
    let site: Site
    let hydrophones: [CustomLocation]

    private let temperaturePoints = [
        TrendPoint(hour: 0, value: 28.8),
        TrendPoint(hour: 4, value: 29.0),
        TrendPoint(hour: 8, value: 29.4),
        TrendPoint(hour: 12, value: 30.0),
        TrendPoint(hour: 16, value: 30.6),
        TrendPoint(hour: 20, value: 31.1),
        TrendPoint(hour: 24, value: 31.2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Demo overview", systemImage: "testtube.2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            mapAndSummary
            metricsGrid
            activityAndTrend
        }
    }

    private var mapAndSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                mapCard
                    .frame(minWidth: 330, maxWidth: .infinity)

                summaryCard
                    .frame(width: 218)
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
            HStack {
                Text("Site Summary")
                    .font(.headline)

                Spacer()

                Text("Demo")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            OverviewSummaryRow(
                title: "Sensors Active",
                value: "\(hydrophones.count) / \(hydrophones.count)",
                systemImage: "sensor"
            )

            OverviewSummaryRow(
                title: "Last Update",
                value: "5 min ago",
                systemImage: "clock"
            )

            OverviewSummaryRow(
                title: "Depth Range",
                value: "5 – 25 m",
                systemImage: "arrow.down.to.line"
            )

            OverviewSummaryRow(
                title: "Route Length",
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
            DemoMetricCard(
                title: "Sea Temperature",
                value: "30.8 °C",
                change: "↑ +0.6 °C",
                tint: .red,
                points: [29.9, 30.1, 30.0, 30.3, 30.5, 30.8]
            )

            DemoMetricCard(
                title: "pH Level",
                value: "7.9",
                change: "↑ +0.1",
                tint: .blue,
                points: [7.8, 7.82, 7.78, 7.86, 7.87, 7.9]
            )

            DemoMetricCard(
                title: "Turbidity",
                value: "1.8 NTU",
                change: "↓ -0.3",
                tint: .green,
                points: [2.2, 2.1, 2.12, 2.0, 1.92, 1.8]
            )

            DemoMetricCard(
                title: "Noise Level",
                value: "142 dB",
                change: "↑ +4 dB",
                tint: .orange,
                points: [134, 135, 136, 136, 140, 142]
            )
        }
    }

    private var activityAndTrend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                recentAlertsCard
                    .frame(minWidth: 290, maxWidth: .infinity)

                temperatureTrendCard
                    .frame(minWidth: 320, maxWidth: .infinity)
            }

            VStack(spacing: 16) {
                recentAlertsCard
                temperatureTrendCard
            }
        }
    }

    private var recentAlertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Alerts")
                    .font(.headline)

                Spacer()

                Text("Demo")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            DemoAlertRow(
                title: "Coral Bleaching Detected",
                detail: "\(site.name) · 10 min ago",
                severity: "High",
                systemImage: "thermometer.high",
                tint: .red
            )

            DemoAlertRow(
                title: "Unusual Noise Levels",
                detail: "Hydrophone 2 · 3 hrs ago",
                severity: "Medium",
                systemImage: "mic.fill",
                tint: .orange
            )

            DemoAlertRow(
                title: "Water Quality Change",
                detail: "\(site.name) · 1 day ago",
                severity: "Low",
                systemImage: "slider.horizontal.3",
                tint: .yellow
            )

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .siteGlassCard(cornerRadius: 18)
    }

    private var temperatureTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Temperature Trend")
                    .font(.headline)

                Spacer()

                Text("Last 24h · Demo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(temperaturePoints) { point in
                AreaMark(
                    x: .value("Hour", point.hour),
                    yStart: .value("Baseline", 28.5),
                    yEnd: .value("Temperature", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Hour", point.hour),
                    y: .value("Temperature", point.value)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .chartYScale(domain: 28.5 ... 31.5)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(timeLabel(for: hour))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(minHeight: 210)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .siteGlassCard(cornerRadius: 18)
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

    private func timeLabel(for hour: Int) -> String {
        switch hour {
        case 0: "00:00"
        case 6: "06:00"
        case 12: "12:00"
        case 18: "18:00"
        default: "Now"
        }
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

private struct DemoMetricCard: View {
    let title: String
    let value: String
    let change: String
    let tint: Color
    let points: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("Demo")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }

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

            Chart(Array(points.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Sample", index),
                    y: .value(title, value)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 34)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .siteGlassCard(cornerRadius: 16)
    }
}

private struct DemoAlertRow: View {
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
                    .lineLimit(1)

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

private struct TrendPoint: Identifiable {
    let hour: Int
    let value: Double

    var id: Int { hour }
}

#Preview {
    SiteOverviewView(
        site: Site(
            name: "Nusa Penida (Demo)",
            startLatitude: -8.7270,
            startLongitude: 115.5440,
            endLatitude: -8.7205,
            endLongitude: 115.5530
        ),
        hydrophones: []
    )
    .frame(width: 900, height: 900)
    .padding()
}
