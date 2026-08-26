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
        colorScheme == .dark ? .white : Color(hex: "0F172A")
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
            VStack(alignment: .leading, spacing: 42) {
                header
                heroSection
                acousticMetricsSection
                historyChartsSection
            }
            .frame(maxWidth: 1_400, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
        }
        .scrollIndicators(.hidden)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
        )
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Back to \(site.name)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.coralystPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.coralystPrimary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Return to site overview")

                Spacer()

                // Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(isOnline ? Color(hex: "10B981") : Color(hex: "94A3B8"))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke((isOnline ? Color(hex: "10B981") : Color.clear).opacity(0.4), lineWidth: 3)
                                .scaleEffect(1.4)
                        )

                    Text(isOnline ? "LIVE STREAMING" : "STANDBY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isOnline ? Color(hex: "10B981") : .secondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5.5)
                .background(
                    (isOnline ? Color(hex: "10B981") : Color(hex: "94A3B8"))
                        .opacity(colorScheme == .dark ? 0.18 : 0.1),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke((isOnline ? Color(hex: "10B981") : Color.secondary).opacity(0.3), lineWidth: 1)
                )
            }

            Text(hydrophone.name)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(primaryText)

            Text("Coordinates: \(hydrophone.latitude.formatted(.number.precision(.fractionLength(5))))°, \(hydrophone.longitude.formatted(.number.precision(.fractionLength(5))))° • Site: \(site.name)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Location Map
    private var heroSection: some View {
        hydrophoneMap
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, y: 3)
    }

    private var hydrophoneMap: some View {
        ZStack(alignment: .topLeading) {
            Map(initialPosition: .region(mapRegion)) {
                Annotation(hydrophone.name, coordinate: hydrophone.coordinate, anchor: .bottom) {
                    VStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.coralystPrimary, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                        Text(hydrophone.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(primaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            // Map Badge
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.coralystPrimary)
                Text(coordinateText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(primaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .padding(12)
        }
    }

    // MARK: - Acoustic Metrics Section
    private var acousticMetricsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)

                Text("Acoustic Health & Bio-Indicators")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryText)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    prominentMetric
                    secondaryMetricsGrid
                }

                VStack(alignment: .leading, spacing: 18) {
                    prominentMetric
                    secondaryMetricsGrid
                }
            }
        }
    }

    private var prominentMetric: some View {
        let trend = metricTrend(for: \.healthScore, fractionDigits: 0)
        return MetricCard(
            title: "Health Composition",
            value: latestSnapshot.map { String(format: "%.0f", $0.healthScore) } ?? "—",
            trend: trend.text,
            status: latestSnapshot?.healthClass ?? "No data",
            trendIsPositive: trend.isPositive,
            primaryText: primaryText,
            isProminent: true
        )
    }

    private var secondaryMetricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
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

        return MetricCard(
            title: title,
            value: value,
            trend: trend.text,
            status: latestSnapshot == nil ? "No data" : "Recorded",
            trendIsPositive: trend.isPositive,
            primaryText: primaryText
        )
    }

    // MARK: - History Trend Charts Section
    private var historyChartsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)

                Text("Historical Spectral Trends")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryText)
            }

            // Prominent Health Composite Trend Chart
            HydrophoneTrendChart(
                title: "Health Composite Score",
                subtitle: "Hypothesis-weighted unsupervised composite calculated from bioacoustic & anthrophony features",
                currentValue: latestSnapshot.map { String(format: "%.0f / 100", $0.healthScore) } ?? "—",
                snapshots: chartSnapshots,
                keyPath: \.healthScore,
                yDomain: 0 ... 100,
                height: 220,
                accentColor: Color(hex: "10B981"),
                primaryText: primaryText
            )

            // 6 Secondary Metric Trend Charts
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 18),
                    GridItem(.flexible(), spacing: 18)
                ],
                spacing: 18
            ) {
                HydrophoneTrendChart(
                    title: "NDSI",
                    subtitle: "Normalized Difference Soundscape Index (-1.0 to +1.0)",
                    currentValue: latestSnapshot.map { String(format: "%.2f", $0.ndsi) } ?? "—",
                    snapshots: chartSnapshots,
                    keyPath: \.ndsi,
                    yDomain: -1 ... 1,
                    accentColor: Color(hex: "0EA5E9"),
                    primaryText: primaryText
                )
                HydrophoneTrendChart(
                    title: "Snap Rate",
                    subtitle: "Snapping shrimp acoustic pulse frequency per minute",
                    currentValue: latestSnapshot.map { String(format: "%.0f /min", $0.snapRatePerMin) } ?? "—",
                    snapshots: chartSnapshots,
                    keyPath: \.snapRatePerMin,
                    yDomain: 0 ... 100,
                    accentColor: Color(hex: "F59E0B"),
                    primaryText: primaryText
                )
                HydrophoneTrendChart(
                    title: "ADI",
                    subtitle: "Acoustic Diversity Index (spectral band entropy)",
                    currentValue: latestSnapshot.map { String(format: "%.2f", $0.adi) } ?? "—",
                    snapshots: chartSnapshots,
                    keyPath: \.adi,
                    yDomain: 0 ... 1,
                    accentColor: Color(hex: "8B5CF6"),
                    primaryText: primaryText
                )
                HydrophoneTrendChart(
                    title: "AEI",
                    subtitle: "Acoustic Evenness Index (spectral band balance)",
                    currentValue: latestSnapshot.map { String(format: "%.2f", $0.aei) } ?? "—",
                    snapshots: chartSnapshots,
                    keyPath: \.aei,
                    yDomain: 0 ... 1,
                    accentColor: Color(hex: "EC4899"),
                    primaryText: primaryText
                )
                HydrophoneTrendChart(
                    title: "Low Frequency dBFS",
                    subtitle: "Low-frequency SPL decibels relative to full scale",
                    currentValue: latestSnapshot.map { String(format: "%.1f dBFS", $0.lowFreqSPL_dB) } ?? "—",
                    snapshots: chartSnapshots,
                    keyPath: \.lowFreqSPL_dB,
                    yDomain: -100 ... 0,
                    accentColor: Color(hex: "6366F1"),
                    primaryText: primaryText
                )
                HydrophoneTrendChart(
                    title: "Biophony Ratio",
                    subtitle: "Proportion of biological noise vs anthrophony in reef band",
                    currentValue: latestSnapshot.map { String(format: "%.2f", $0.biophonyRatio) } ?? "—",
                    snapshots: chartSnapshots,
                    keyPath: \.biophonyRatio,
                    yDomain: 0 ... 1,
                    accentColor: Color(hex: "10B981"),
                    primaryText: primaryText
                )
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
        "\(hydrophone.latitude.formatted(.number.precision(.fractionLength(4)))), \(hydrophone.longitude.formatted(.number.precision(.fractionLength(4))))"
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

// MARK: - Modern Elevated Trend Chart Component
private struct HydrophoneTrendChart: View {
    let title: String
    let subtitle: String
    let currentValue: String
    let snapshots: [HealthSnapshotRecord]
    let keyPath: KeyPath<HealthSnapshotRecord, Double>
    let yDomain: ClosedRange<Double>
    var height: CGFloat = 175
    var accentColor: Color = Color.coralystPrimary
    let primaryText: Color

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Title, Subtitle & Current Value Badge
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(primaryText)

                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Current Latest Value Pill
                Text(currentValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1), in: Capsule())
            }

            if snapshots.count < 2 {
                ContentUnavailableView {
                    Label("Awaiting telemetry data", systemImage: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 13, weight: .medium))
                } description: {
                    Text("Telemetry readings will graph automatically once received.")
                        .font(.system(size: 11))
                }
                .frame(maxWidth: .infinity, minHeight: height)
            } else {
                Chart(snapshots) { snapshot in
                    // Area Gradient Fill below curve
                    AreaMark(
                        x: .value("Time", snapshot.windowStart),
                        y: .value(title, snapshot[keyPath: keyPath])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15),
                                accentColor.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line Stroke
                    LineMark(
                        x: .value("Time", snapshot.windowStart),
                        y: .value(title, snapshot[keyPath: keyPath])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Data Point Nodes
                    PointMark(
                        x: .value("Time", snapshot.windowStart),
                        y: .value(title, snapshot[keyPath: keyPath])
                    )
                    .foregroundStyle(accentColor)
                    .symbolSize(22)
                }
                .chartYScale(domain: yDomain)
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.primary.opacity(0.08))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.primary.opacity(0.08))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: height)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isHovered ? accentColor.opacity(0.4) : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06),
                    lineWidth: 1
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04),
            radius: 8,
            y: 3
        )
        .onHover { isHovered = $0 }
    }
}

private struct HydrophoneDetailPreviewSample {
    let container: ModelContainer
    let site: Site
    let hydrophone: CustomLocation

    static func make() -> Self {
        let container = try! ModelContainer(
            for: Site.self,
            CustomLocation.self,
            HealthSnapshotRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let site = Site(
            name: "Pemuteran Reef",
            startLatitude: -8.1287,
            startLongitude: 114.6608,
            endLatitude: -8.1322,
            endLongitude: 114.6715
        )
        let hydrophone = CustomLocation(
            name: "Dragon Structure",
            latitude: -8.1304,
            longitude: 114.6642,
            microphoneDeviceID: "preview-dragon-structure",
            microphoneDeviceName: "Preview microphone",
            site: site
        )

        context.insert(site)
        context.insert(hydrophone)

        let healthScores = [76.0, 77.0, 75.0, 78.0, 77.0, 81.0, 80.0, 80.0]
        let ndsiValues = [0.42, 0.49, 0.37, 0.57, 0.50, 0.61, 0.64, 0.68]
        let snapRates = [52.0, 56.0, 49.0, 61.0, 57.0, 63.0, 54.0, 58.0]

        for index in healthScores.indices {
            let offset = Double(index)
            let record = HealthSnapshotRecord(
                siteName: site.name,
                hydrophoneName: hydrophone.name,
                windowStart: .now.addingTimeInterval(-Double(healthScores.count - 1 - index) * 3_600),
                healthScore: healthScores[index],
                healthClass: "Healthy",
                aci: 0.55 + offset * 0.015,
                adi: 0.48 + offset * 0.025,
                aei: 0.58 - offset * 0.008,
                ndsi: ndsiValues[index],
                lowFreqSPL_dB: -57 + offset * 0.7,
                snapRatePerMin: snapRates[index],
                biophonyRatio: 0.46 + offset * 0.018,
                anthrophonyRatio: 0.32 - offset * 0.01,
                blastEventCountLastHour: 0,
                topDrivers: "ndsi,snapRatePerMin",
                narrative: "Preview reading",
                narrativeSource: "preview",
                note: "Preview-only health snapshot."
            )
            context.insert(record)
        }

        try? context.save()
        return Self(container: container, site: site, hydrophone: hydrophone)
    }
}

private let hydrophoneDetailPreviewSample = HydrophoneDetailPreviewSample.make()

#Preview("With chart data") {
    HydrophoneDetailView(
        site: hydrophoneDetailPreviewSample.site,
        hydrophone: hydrophoneDetailPreviewSample.hydrophone,
        onBack: {}
    )
    .environmentObject(DetectionStore())
    .modelContainer(hydrophoneDetailPreviewSample.container)
    .frame(width: 1_200, height: 1_600)
    .padding()
}
