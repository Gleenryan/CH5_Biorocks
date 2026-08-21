import Charts
import Foundation
import MapKit
import SwiftData
import SwiftUI

struct HydrophoneDetailView: View {
    let site: Site
    let hydrophone: CustomLocation
    let onBack: () -> Void

    @EnvironmentObject private var store: DetectionStore
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \HealthSnapshotRecord.windowStart, order: .reverse) private var snapshots: [HealthSnapshotRecord]

    private var primaryText: Color {
        colorScheme == .dark ? .primary : .coralystText
    }

    private var hydrophoneSnapshots: [HealthSnapshotRecord] {
        snapshots.filter {
            $0.siteName == site.name
                && $0.hydrophoneName.localizedCaseInsensitiveCompare(hydrophone.name) == .orderedSame
        }
    }

    private var chartSnapshots: [HealthSnapshotRecord] {
        hydrophoneSnapshots.reversed()
    }

    private var latestSnapshot: HealthSnapshotRecord? {
        hydrophoneSnapshots.first
    }

    private var liveStatus: LiveHydrophoneStatus? {
        store.liveHydrophones.first { status in
            status.simulatorDeviceID == hydrophone.microphoneDeviceID
                || (
                    status.name.localizedCaseInsensitiveCompare(hydrophone.name) == .orderedSame
                        && status.siteName.localizedCaseInsensitiveCompare(site.name) == .orderedSame
                )
        }
    }

    private var isOnline: Bool {
        liveStatus?.connected == true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                mapAndPlaceholder
                status
                historyCharts
            }
            .frame(maxWidth: 1_500, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(primaryText)

            Divider()
                .frame(height: 24)

            Text("\(hydrophone.name) Details")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(primaryText)
                .lineLimit(1)

            Label(isOnline ? "Online" : "Offline", systemImage: isOnline ? "checkmark.circle.fill" : "circle.fill")
                .font(.headline)
                .foregroundStyle(isOnline ? .green : .secondary)

            Spacer(minLength: 0)
        }
    }

    private var mapAndPlaceholder: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                hydrophoneMap
                Color.green
                    .accessibilityLabel("Reserved placeholder panel")
            }
            .frame(minWidth: 760)
            .frame(height: 300)

            VStack(spacing: 0) {
                hydrophoneMap
                    .frame(height: 260)
                Color.green
                    .frame(height: 220)
                    .accessibilityLabel("Reserved placeholder panel")
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(primaryText.opacity(colorScheme == .dark ? 0.35 : 0.75), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.10), radius: 7, y: 3)
    }

    private var hydrophoneMap: some View {
        Map(initialPosition: .region(mapRegion)) {
            Annotation("Hydrophone", coordinate: hydrophone.coordinate, anchor: .bottom) {
                VStack(spacing: 7) {
                    Text(coordinateText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 3)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.green)
                        .frame(width: 30, height: 30)
                        .background(.regularMaterial, in: Circle())
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(primaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    prominentMetric
                    secondaryMetrics
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 16) {
                    prominentMetric
                    secondaryMetrics
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var prominentMetric: some View {
        let trend = metricTrend(for: \.healthScore, fractionDigits: 0)
        return HomeMetricCard(
            title: "Health Composition",
            value: latestSnapshot.map { String(format: "%.0f", $0.healthScore) } ?? "—",
            trend: trend.text,
            status: latestSnapshot?.healthClass ?? "No data",
            trendIsPositive: trend.isPositive,
            primaryText: primaryText,
            isProminent: true
        )
    }

    private var secondaryMetrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.fixed(180), spacing: 16),
                GridItem(.fixed(180), spacing: 16),
                GridItem(.fixed(180), spacing: 16)
            ],
            spacing: 16
        ) {
            metricCard(title: "NDSI", keyPath: \.ndsi, fractionDigits: 2)
            metricCard(title: "ADI", keyPath: \.adi, fractionDigits: 2)
            metricCard(title: "Low Freq dBFS", keyPath: \.lowFreqSPL_dB, fractionDigits: 1, lowerIsBetter: true)
            metricCard(title: "Snap Rate / min", keyPath: \.snapRatePerMin, fractionDigits: 0)
            metricCard(title: "AEI", keyPath: \.aei, fractionDigits: 2)
            metricCard(title: "Biophony Ratio", keyPath: \.biophonyRatio, fractionDigits: 2)
        }
    }

    private func metricCard(
        title: String,
        keyPath: KeyPath<HealthSnapshotRecord, Double>,
        fractionDigits: Int,
        lowerIsBetter: Bool = false
    ) -> some View {
        let trend = metricTrend(
            for: keyPath,
            fractionDigits: fractionDigits,
            lowerIsBetter: lowerIsBetter
        )
        let value = latestSnapshot.map { String(format: "%.\(fractionDigits)f", $0[keyPath: keyPath]) } ?? "—"

        return HomeMetricCard(
            title: title,
            value: value,
            trend: trend.text,
            status: latestSnapshot == nil ? "No data" : "Recorded",
            trendIsPositive: trend.isPositive,
            primaryText: primaryText
        )
    }

    private var historyCharts: some View {
        VStack(alignment: .leading, spacing: 22) {
            HydrophoneTrendChart(
                title: "Health Composite",
                subtitle: "A hypothesis-weighted unsupervised composite calculated from acoustic features.",
                snapshots: chartSnapshots,
                keyPath: \.healthScore,
                yDomain: 0 ... 100,
                height: 230,
                primaryText: primaryText
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 22
            ) {
                HydrophoneTrendChart(title: "NDSI", subtitle: "Normalized Difference Soundscape Index.", snapshots: chartSnapshots, keyPath: \.ndsi, yDomain: -1 ... 1, primaryText: primaryText)
                HydrophoneTrendChart(title: "Snap Rate", subtitle: "Snapping shrimp noise rate per minute.", snapshots: chartSnapshots, keyPath: \.snapRatePerMin, yDomain: 0 ... 100, primaryText: primaryText)
                HydrophoneTrendChart(title: "ADI", subtitle: "Acoustic Diversity Index.", snapshots: chartSnapshots, keyPath: \.adi, yDomain: 0 ... 1, primaryText: primaryText)
                HydrophoneTrendChart(title: "AEI", subtitle: "Acoustic Evenness Index.", snapshots: chartSnapshots, keyPath: \.aei, yDomain: 0 ... 1, primaryText: primaryText)
                HydrophoneTrendChart(title: "Low Freq dBFS", subtitle: "Low-frequency decibels relative to full scale.", snapshots: chartSnapshots, keyPath: \.lowFreqSPL_dB, yDomain: -100 ... 0, primaryText: primaryText)
                HydrophoneTrendChart(title: "Biophony", subtitle: "Collective noise produced by living organisms in the reef ecosystem.", snapshots: chartSnapshots, keyPath: \.biophonyRatio, yDomain: 0 ... 1, primaryText: primaryText)
            }
        }
    }

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: hydrophone.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )
    }

    private var coordinateText: String {
        "\(hydrophone.latitude.formatted(.number.precision(.fractionLength(5)))), \(hydrophone.longitude.formatted(.number.precision(.fractionLength(5))))"
    }

    private func metricTrend(
        for keyPath: KeyPath<HealthSnapshotRecord, Double>,
        fractionDigits: Int,
        lowerIsBetter: Bool = false
    ) -> HydrophoneMetricTrend {
        guard hydrophoneSnapshots.count >= 2 else {
            return HydrophoneMetricTrend(text: nil, isPositive: true)
        }

        let change = hydrophoneSnapshots[0][keyPath: keyPath] - hydrophoneSnapshots[1][keyPath: keyPath]
        return HydrophoneMetricTrend(
            text: String(format: "%.\(fractionDigits)f", abs(change)),
            isPositive: lowerIsBetter ? change < 0 : change >= 0
        )
    }
}

private struct HydrophoneMetricTrend {
    let text: String?
    let isPositive: Bool
}

private struct HydrophoneTrendChart: View {
    let title: String
    let subtitle: String
    let snapshots: [HealthSnapshotRecord]
    let keyPath: KeyPath<HealthSnapshotRecord, Double>
    let yDomain: ClosedRange<Double>
    var height: CGFloat = 190
    let primaryText: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(primaryText)

                Text(subtitle)
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if snapshots.count < 2 {
                ContentUnavailableView {
                    Label("No data yet", systemImage: "chart.line.downtrend.xyaxis")
                } description: {
                    Text("This hydrophone needs at least two saved readings to show a trend.")
                }
                .frame(maxWidth: .infinity, minHeight: height)
            } else {
                Chart(snapshots) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.windowStart),
                        y: .value(title, snapshot[keyPath: keyPath])
                    )
                    .foregroundStyle(Color.coralystText)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Time", snapshot.windowStart),
                        y: .value(title, snapshot[keyPath: keyPath])
                    )
                    .foregroundStyle(Color.coralystText)
                    .symbolSize(28)
                }
                .chartYScale(domain: yDomain)
                .chartLegend(.hidden)
                .frame(height: height)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }
}

#Preview {
    HydrophoneDetailView(
        site: Site(
            name: "Pemuteran",
            startLatitude: -8.1287,
            startLongitude: 114.6608,
            endLatitude: -8.1322,
            endLongitude: 114.6715
        ),
        hydrophone: CustomLocation(name: "Hydrophone 1", latitude: -8.1304, longitude: 114.6642),
        onBack: {}
    )
    .environmentObject(DetectionStore())
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 1_200, height: 900)
    .padding()
}
