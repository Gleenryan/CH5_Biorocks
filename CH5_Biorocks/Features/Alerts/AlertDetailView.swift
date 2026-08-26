import MapKit
import SwiftUI
import AppKit

struct AlertDetailView: View {
    let event: BlastDetectionEvent
    let sites: [Site]
    let onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isCopied = false
    @State private var isAcknowledged = false

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(hex: "0F172A")
    }

    private var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var site: Site? {
        sites.first {
            $0.name.localizedCaseInsensitiveCompare(event.siteName) == .orderedSame
        }
    }

    private var hydrophone: CustomLocation? {
        guard let site else { return nil }

        let eventID = normalizedDeviceID(event.hydrophoneId)
        return site.hydrophones.first { candidate in
            (
                !eventID.isEmpty
                    && (
                        normalizedDeviceID(candidate.microphoneDeviceID) == eventID
                            || candidate.id.uuidString.caseInsensitiveCompare(eventID) == .orderedSame
                    )
            )
                || (
                    candidate.name.localizedCaseInsensitiveCompare(event.hydrophoneName) == .orderedSame
                        && candidate.site?.name.localizedCaseInsensitiveCompare(event.siteName) == .orderedSame
                )
        }
    }

    private var focusCoordinate: CLLocationCoordinate2D? {
        hydrophone?.coordinate ?? site?.coverageCenterCoordinate
    }

    private var mapHydrophones: [CustomLocation] {
        site?.hydrophones ?? []
    }

    private var title: String {
        let headline = event.narrative
            .split(separator: "\n", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let headline, !headline.isEmpty {
            return headline
        }
        return "Blast Detection Event"
    }

    private var narrativeDescription: String {
        let lines = event.narrative
            .split(separator: "\n", maxSplits: 1)
        if lines.count > 1 {
            return lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return event.narrative
    }

    private var locationName: String {
        site?.name ?? event.siteName
    }

    private var severityColor: Color {
        switch event.severity.lowercased() {
        case "high", "critical", "danger":
            return Color(hex: "EF4444")
        case "medium", "warning":
            return Color(hex: "F59E0B")
        default:
            return Color(hex: "10B981")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                topNavigationBar
                incidentHeroCard
                if !event.recommendedAction.isEmpty {
                    recommendedActionBanner
                }
                metricsOverviewGrid
                spatialMapSection
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

    // MARK: - 1. Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Back to Alerts")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.coralystPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7.5)
                .background(Color.coralystPrimary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Return to alerts list")

            Spacer()

            // Copy Report Button
            Button(action: copyIncidentReport) {
                HStack(spacing: 6) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isCopied ? "Copied" : "Copy Report")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Copy incident summary to clipboard")

            // Acknowledge Button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAcknowledged.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAcknowledged ? "checkmark.circle.fill" : "bell.slash")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isAcknowledged ? "Acknowledged" : "Acknowledge")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(isAcknowledged ? Color(hex: "10B981") : Color.coralystPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    (isAcknowledged ? Color(hex: "10B981") : Color.coralystPrimary)
                        .opacity(colorScheme == .dark ? 0.18 : 0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke((isAcknowledged ? Color(hex: "10B981") : Color.coralystPrimary).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 2. Incident Hero Card
    private var incidentHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                // Severity Tag Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(severityColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(severityColor.opacity(0.4), lineWidth: 3)
                                .scaleEffect(1.4)
                        )

                    Text("\(event.severity.uppercased()) SEVERITY")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(severityColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(severityColor.opacity(colorScheme == .dark ? 0.18 : 0.1), in: Capsule())
                .overlay(Capsule().stroke(severityColor.opacity(0.35), lineWidth: 1))

                // Detection Class Pill
                HStack(spacing: 5) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 11))
                    Text(event.topClass.capitalized)
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5.5)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), in: Capsule())

                Spacer()

                // Timestamp
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                    Text(event.onsetTime.formatted(date: .abbreviated, time: .standard))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(narrativeDescription)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(primaryText.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Location Breadcrumb Row
            HStack(spacing: 16) {
                Label(locationName, systemImage: "map.fill")
                Label(event.hydrophoneName, systemImage: "mic.fill")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    severityColor.opacity(colorScheme == .dark ? 0.25 : 0.15),
                    lineWidth: 1.5
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 12, y: 4)
    }

    // MARK: - 3. Recommended Action Banner
    private var recommendedActionBanner: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(severityColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(severityColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("RECOMMENDED PROTOCOL & ACTION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(severityColor)
                    .tracking(0.6)

                Text(event.recommendedAction)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(primaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(severityColor.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.03), radius: 8, y: 2)
    }

    // MARK: - 4. Key Metrics Overview Grid (Confidence & Hydrophone Node)
    private var metricsOverviewGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 280), spacing: 20),
                GridItem(.flexible(minimum: 280), spacing: 20)
            ],
            spacing: 20
        ) {
            metricStatCard(
                title: "Confidence Score",
                value: String(format: "%.1f%%", event.pBlast * 100),
                subtitle: "\(event.topClass.capitalized) signature certainty",
                icon: "chart.bar.fill",
                accentColor: severityColor,
                progress: event.pBlast
            )

            metricStatCard(
                title: "Hydrophone Node",
                value: event.hydrophoneName,
                subtitle: focusCoordinate.map { "\($0.latitude.formatted(.number.precision(.fractionLength(4))))°, \($0.longitude.formatted(.number.precision(.fractionLength(4))))° • \(locationName)" } ?? locationName,
                icon: "mic.fill",
                accentColor: Color.coralystPrimary
            )
        }
    }

    private func metricStatCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        accentColor: Color,
        progress: Double? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(accentColor.gradient)
                            .frame(width: max(8, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                    }
                }
                .frame(height: 7)
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 8, y: 2)
    }

    // MARK: - 5. Spatial Map & Hydrophone Array Section
    private var spatialMapSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)

                Text("Spatial Hydrophone Array & Localization")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(primaryText)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    mapContent
                        .frame(minWidth: 460, maxWidth: .infinity)
                    exhibitionSidePanel
                        .frame(width: 360)
                }
                .frame(height: 380)

                VStack(spacing: 0) {
                    mapContent
                        .frame(height: 320)
                    exhibitionSidePanel
                        .frame(height: 240)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(cardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, y: 3)
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        if let focusCoordinate {
            ZStack(alignment: .topLeading) {
                Map(initialPosition: .region(mapRegion(around: focusCoordinate))) {
                    ForEach(mapHydrophones) { candidate in
                        Annotation(candidate.name, coordinate: candidate.coordinate) {
                            VStack(spacing: 3) {
                                Image(systemName: isAlertHydrophone(candidate) ? "mic.fill" : "mic.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(
                                        isAlertHydrophone(candidate) ? Color(hex: "EF4444") : Color.coralystPrimary,
                                        in: Circle()
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 3)

                                Text(candidate.name)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(primaryText)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                    }

                    Annotation("Detonation Epicenter", coordinate: focusCoordinate) {
                        ZStack {
                            Circle()
                                .fill(severityColor.opacity(0.2))
                                .frame(width: 60, height: 60)

                            Circle()
                                .stroke(severityColor.opacity(0.6), lineWidth: 2)
                                .frame(width: 44, height: 44)

                            Circle()
                                .fill(severityColor.gradient)
                                .frame(width: 18, height: 18)
                                .shadow(color: severityColor.opacity(0.6), radius: 6)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }

                // Coordinate Overlay Pill
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.coralystPrimary)
                    Text("\(focusCoordinate.latitude.formatted(.number.precision(.fractionLength(5)))), \(focusCoordinate.longitude.formatted(.number.precision(.fractionLength(5))))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(primaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5.5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                .padding(14)
            }
        } else {
            ContentUnavailableView {
                Label("Location unavailable", systemImage: "map")
            } description: {
                Text("This alert is not linked to a saved Site or hydrophone coordinate.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var exhibitionSidePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)
                Text("ACOUSTIC SCENE & TELEMETRY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.coralystPrimary)
                    .tracking(0.8)
            }

            Text("Side-by-side verification stream captured on \(event.hydrophoneName).")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(primaryText)
                .lineSpacing(2)

            // Audio Waveform Simulation Graphic
            HStack(alignment: .center, spacing: 3) {
                ForEach(0 ..< 28, id: \.self) { i in
                    let height: CGFloat = waveformHeight(for: i)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(waveformColor(for: i))
                        .frame(width: 4, height: height)
                }
            }
            .frame(height: 52)
            .padding(.vertical, 4)

            // Confidence Level Bar
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Detonation Probability")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", event.pBlast * 100))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(severityColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(severityColor.gradient)
                            .frame(width: max(8, geo.size.width * CGFloat(event.pBlast)))
                    }
                }
                .frame(height: 7)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "10B981"))
                    .frame(width: 6, height: 6)
                Text("Hydrophone Ingress Active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Color.coralystPrimary.opacity(colorScheme == .dark ? 0.06 : 0.03)
        )
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        // High spike in the center representing impulsive blast
        if index >= 11 && index <= 16 {
            return CGFloat([36, 48, 52, 44, 38, 28][index - 11])
        }
        let values: [CGFloat] = [8, 12, 10, 14, 16, 11, 9, 15, 12, 18, 22, 0, 0, 0, 0, 0, 0, 18, 14, 11, 15, 12, 9, 13, 10, 8, 11, 7]
        return values[index % values.count]
    }

    private func waveformColor(for index: Int) -> Color {
        if index >= 11 && index <= 16 {
            return severityColor
        }
        return Color.coralystPrimary.opacity(0.6)
    }

    private func mapRegion(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let radius = site?.coverageRadiusMeters ?? 0
        let latitudeDelta = min(max(radius / 55_500, 0.012), 0.08)
        let longitudeDelta = min(max(radius / 55_500, 0.012), 0.08)

        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )
    }

    private func isAlertHydrophone(_ candidate: CustomLocation) -> Bool {
        let eventID = normalizedDeviceID(event.hydrophoneId)
        return (
            !eventID.isEmpty
                && (
                    normalizedDeviceID(candidate.microphoneDeviceID) == eventID
                        || candidate.id.uuidString.caseInsensitiveCompare(eventID) == .orderedSame
                )
        )
            || (
                candidate.name.localizedCaseInsensitiveCompare(event.hydrophoneName) == .orderedSame
                    && candidate.site?.name.localizedCaseInsensitiveCompare(event.siteName) == .orderedSame
            )
    }

    private func normalizedDeviceID(_ id: String?) -> String {
        guard let id else { return "" }
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.lowercased().hasPrefix("sim://") {
            return String(normalized.dropFirst(6)).lowercased()
        }
        return normalized.lowercased()
    }

    private func copyIncidentReport() {
        let report = """
        [CORALYST INCIDENT REPORT]
        Event: \(title)
        Severity: \(event.severity.capitalized)
        Site: \(locationName)
        Hydrophone: \(event.hydrophoneName)
        Detection Time: \(event.onsetTime.formatted(date: .abbreviated, time: .standard))
        Confidence: \(String(format: "%.1f%%", event.pBlast * 100)) (\(event.topClass))
        Recommended Action: \(event.recommendedAction)
        Narrative: \(narrativeDescription)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)

        withAnimation(.spring(response: 0.3)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

#Preview {
    AlertDetailView(
        event: BlastDetectionEvent(
            siteName: "Indonesia N1",
            hydrophoneName: "Hydrophone 1",
            hydrophoneId: "hydrophone-1",
            source: "reef_pipeline",
            scenarioId: "blast_in_ambient",
            onsetTime: .now,
            pBlast: 0.94,
            topClass: "blast",
            topConfidence: 0.94,
            narrative: "Suspected Blast Event\nHigh-energy impulsive detonation signature detected with sharp rise time and dominant low-frequency shockwave.",
            narrativeSource: "Core ML Classifier",
            severity: "High",
            recommendedAction: "Dispatch local marine patrol for inspection and deploy emergency acoustic surveillance protocol."
        ),
        sites: [
            Site(
                name: "Indonesia N1",
                startLatitude: -8.1287,
                startLongitude: 114.6608,
                endLatitude: -8.1322,
                endLongitude: 114.6715
            )
        ],
        onBack: {}
    )
    .frame(width: 1_200, height: 900)
    .padding()
}
