import SwiftUI
import MapKit
import SwiftData

struct DashboardView: View {
    let sites: [Site]
    let onAddSite: () -> Void
    var onViewAllAlerts: () -> Void = {}
    var onSelectAlert: (BlastDetectionEvent) -> Void = { _ in }

    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse)
    private var events: [BlastDetectionEvent]
    @Query(sort: \HealthSnapshotRecord.windowStart, order: .reverse)
    private var snapshots: [HealthSnapshotRecord]
    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(hex: "0F172A")
    }

    private var latestSnapshot: HealthSnapshotRecord? {
        snapshots.first
    }

    private var recentEvents: [BlastDetectionEvent] {
        Array(events.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 38) {
                header
                recentAlertsSection
                sitesSummarySection
                siteStatusSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            HStack(alignment: .center, spacing: 16) {
                Text("All Sites Overview")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(primaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                // Live Status Pill
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(hex: "10B981"))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "10B981").opacity(0.35), lineWidth: 3)
                                .scaleEffect(1.4)
                        )

                    Text("LIVE MONITORING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "10B981"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Color(hex: "10B981").opacity(colorScheme == .dark ? 0.18 : 0.1),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "10B981").opacity(0.3), lineWidth: 1)
                )
            }

            Text("Real-time reef acoustic intelligence, bio-acoustic metrics & blast detection")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Recent Alerts
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

                    if !events.isEmpty {
                        Text("\(events.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(Color(hex: "EF4444"), in: Capsule())
                    }
                }

                Spacer()

                Button(action: onViewAllAlerts) {
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

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 20)],
                spacing: 20
            ) {
                recentAlertCards
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var recentAlertCards: some View {
        if recentEvents.isEmpty {
            ForEach(AlertSummary.preview) { alert in
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

    // MARK: - Sites Summary
    private var sitesSummarySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)

                Text("Sites Summary")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryText)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 200, maximum: 380), spacing: 18)],
                spacing: 18
            ) {
                metricCards
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        MetricCard(
            title: "Health Composition",
            value: latestSnapshot.map { String(format: "%.0f", $0.healthScore) } ?? "80",
            trend: "+ 2",
            status: latestSnapshot?.healthClass ?? "Healthy",
            trendIsPositive: true,
            primaryText: primaryText
        )
        MetricCard(
            title: "NDSI",
            value: latestSnapshot.map { String(format: "%.2f", $0.ndsi) } ?? "0.78",
            trend: "+ 0.087",
            status: "Good",
            trendIsPositive: true,
            primaryText: primaryText
        )
        MetricCard(
            title: "Snap Rate / min",
            value: latestSnapshot.map { String(format: "%.0f", $0.snapRatePerMin) } ?? "53",
            trend: "− 0.087",
            status: "Normal",
            trendIsPositive: false,
            primaryText: primaryText
        )
        MetricCard(
            title: "Low Freq dBFS",
            value: latestSnapshot.map { String(format: "%.1f", $0.lowFreqSPL_dB) } ?? "−54.1",
            trend: "− 3.3",
            status: "Normal",
            trendIsPositive: false,
            primaryText: primaryText
        )
        MetricCard(
            title: "Bomb Alerts",
            value: "\(events.count)",
            trend: nil,
            status: events.isEmpty ? "Clear" : "Check needed",
            trendIsPositive: events.isEmpty,
            primaryText: primaryText
        )
    }

    // MARK: - Site Status Card & Map
    private var siteStatusSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)

                Text("Site Status & Spatial Monitoring")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryText)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 28) {
                    siteMap
                        .frame(minWidth: 320, idealWidth: 460, maxWidth: 500)

                    siteStatusTable
                        .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 24) {
                    siteMap
                        .frame(maxWidth: .infinity, alignment: .leading)
                    siteStatusTable
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04),
                radius: 10,
                y: 3
            )
        }
    }

    private var siteMap: some View {
        ZStack(alignment: .topLeading) {
            Map {
                ForEach(sites) { site in
                    MapCircle(center: site.coverageCenterCoordinate, radius: max(site.coverageRadiusMeters, 1))
                        .foregroundStyle(Color.coralystPrimary.opacity(0.15))
                        .stroke(Color.coralystPrimary, lineWidth: 2)

                    Marker(site.name, systemImage: "water.waves", coordinate: site.coverageCenterCoordinate)
                        .tint(Color.coralystPrimary)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapScaleView()
                MapCompass()
            }

            // Top Badge Overlay on Map
            HStack(spacing: 6) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.coralystPrimary)
                Text("\(sites.count) Monitored \(sites.count == 1 ? "Site" : "Sites")")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(primaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .padding(14)

            if sites.isEmpty {
                ContentUnavailableView {
                    Label("No Sites Registered", systemImage: "map")
                } description: {
                    Text("Add your first Site to display its real-time status and telemetry.")
                } actions: {
                    Button("Add Site", action: onAddSite)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.coralystPrimary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
        }
        .frame(height: 350)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        )
    }

    private var siteStatusTable: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Row
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
                GridRow {
                    tableHeader("SITE")
                    tableHeader("HEALTH")
                    tableHeader("NDSI")
                    tableHeader("SNAP RATE")
                    tableHeader("ALERTS")
                }

                Divider()
                    .gridCellColumns(5)
                    .padding(.vertical, 4)

                ForEach(sites) { site in
                    let siteAlerts = events.filter { $0.siteName == site.name }
                    let health = healthValue(for: site)

                    GridRow {
                        // Site Name with indicator dot
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.coralystPrimary)
                                .frame(width: 7, height: 7)
                            Text(site.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(primaryText)
                                .lineLimit(1)
                        }

                        // Health Score Pill
                        HStack(spacing: 4) {
                            Text(health)
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundStyle(health == "—" ? .secondary : Color(hex: "10B981"))
                        }

                        // NDSI
                        Text(ndsiValue(for: site))
                            .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(primaryText)

                        // Snap Rate
                        Text(snapRateValue(for: site))
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(primaryText)

                        // Alerts Badge
                        HStack(spacing: 4) {
                            if siteAlerts.isEmpty {
                                Text("0 Clear")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(hex: "10B981"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(Color(hex: "10B981").opacity(0.12), in: Capsule())
                            } else {
                                Text("\(siteAlerts.count) Alert\(siteAlerts.count > 1 ? "s" : "")")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "EF4444"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(Color(hex: "EF4444").opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 6)

                    Divider()
                        .gridCellColumns(5)
                        .opacity(0.35)
                }
            }

            if sites.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No active monitoring sites")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 36)
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 6)
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
        return String(format: "%.0f/m", snapshot.snapRatePerMin)
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }
}

#Preview {
    DashboardView(
        sites: [
            Site(name: "Amed 1", startLatitude: -8.3405, startLongitude: 115.6582, endLatitude: -8.3385, endLongitude: 115.6612),
            Site(name: "Pemuteran 1", startLatitude: -8.1287, startLongitude: 114.6608, endLatitude: -8.1322, endLongitude: 114.6715)
        ],
        onAddSite: {}
    )
    .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
    .frame(width: 1000, height: 720)
}
