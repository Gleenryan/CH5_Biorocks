import MapKit
import SwiftUI

struct AlertDetailView: View {
    let event: BlastDetectionEvent
    let sites: [Site]
    let onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color {
        colorScheme == .dark ? .primary : .coralystText
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
        return "Blast Detection"
    }

    private var locationName: String {
        site?.name ?? event.siteName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                detailRow(title: "Location", value: locationName)
                detailRow(title: "Detection Time", value: "-")
                alertMap
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
                .frame(height: 28)

            Text(title)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(primaryText)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(primaryText)

            Spacer(minLength: 16)

            Text(value)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var alertMap: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                mapContent
                Color.green
                    .accessibilityLabel("Reserved placeholder panel")
            }
            .frame(minWidth: 760)
            .frame(height: 440)

            VStack(spacing: 0) {
                mapContent
                    .frame(height: 360)
                Color.green
                    .frame(height: 180)
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

    @ViewBuilder
    private var mapContent: some View {
        if let focusCoordinate {
            Map(initialPosition: .region(mapRegion(around: focusCoordinate))) {
                ForEach(mapHydrophones) { candidate in
                    Annotation(candidate.name, coordinate: candidate.coordinate) {
                        Image(systemName: isAlertHydrophone(candidate) ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isAlertHydrophone(candidate) ? Color.red : Color.green)
                            .frame(width: 30, height: 30)
                            .background(.regularMaterial, in: Circle())
                    }
                    .annotationTitles(.hidden)
                }

                Annotation("Alert location", coordinate: focusCoordinate) {
                    ZStack {
                        Circle()
                            .fill(.red.gradient)
                            .frame(width: 76, height: 76)
                            .shadow(color: .red.opacity(0.35), radius: 10)

                        Circle()
                            .fill(.white.opacity(0.72))
                            .frame(width: 28, height: 28)
                            .blur(radius: 5)
                    }
                    .accessibilityLabel("Alert location")
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
        } else {
            ContentUnavailableView {
                Label("Location unavailable", systemImage: "map")
            } description: {
                Text("This alert is not linked to a saved Site or hydrophone.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
        }
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
}

#Preview {
    AlertDetailView(
        event: BlastDetectionEvent(
            siteName: "Pemuteran",
            hydrophoneName: "Hydrophone 1",
            hydrophoneId: "hydrophone-1",
            source: "simulator",
            scenarioId: "blast",
            onsetTime: .now,
            pBlast: 0.88,
            topClass: "blast",
            topConfidence: 0.88,
            narrative: "Suspected Bombing\nTwo loud bangs were detected.",
            narrativeSource: "template",
            severity: "high",
            recommendedAction: "Review the alert."
        ),
        sites: [
            Site(
                name: "Pemuteran",
                startLatitude: -8.1287,
                startLongitude: 114.6608,
                endLatitude: -8.1322,
                endLongitude: 114.6715
            )
        ],
        onBack: {}
    )
    .frame(width: 1_300, height: 760)
    .padding()
}
