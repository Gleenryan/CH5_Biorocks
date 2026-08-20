import SwiftUI
import MapKit

struct SiteFormOverlay: View {
    var onCancel: () -> Void
    var onSubmit: (String, Double, Double, Double, Double) -> Void

    @State private var name = ""
    @State private var startLatitude = "-8.128667"
    @State private var startLongitude = "114.660816"
    @State private var endLatitude = "-8.132200"
    @State private var endLongitude = "114.671500"
    @State private var selectedMapPoint: SiteFormMapPoint?

    private let mapCoordinateSpace = "site-form-map"

    private var parsedStartCoordinate: CLLocationCoordinate2D? {
        coordinate(latitude: startLatitude, longitude: startLongitude)
    }

    private var parsedEndCoordinate: CLLocationCoordinate2D? {
        coordinate(latitude: endLatitude, longitude: endLongitude)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && parsedStartCoordinate != nil && parsedEndCoordinate != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("NEW SITE")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.secondary.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .keyboardShortcut(.cancelAction)
            }

            SiteTextField(title: "Site name", placeholder: "e.g. Pemuteran Reef", text: $name)

            HStack(alignment: .top, spacing: 22) {
                coordinateFields(
                    title: "START",
                    latitude: $startLatitude,
                    longitude: $startLongitude
                )

                coordinateFields(
                    title: "FINISH",
                    latitude: $endLatitude,
                    longitude: $endLongitude
                )
            }

            mapPreview
                .frame(height: 205)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }

            HStack(spacing: 12) {
                Text("Coordinates must use latitude −90…90 and longitude −180…180.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(SiteSecondaryButtonStyle())

                Button("Create Site", action: submit)
                    .buttonStyle(SitePrimaryButtonStyle())
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 650)
        .siteGlassCard(cornerRadius: 18)
        .shadow(color: .black.opacity(0.22), radius: 30, y: 15)
    }

    private func coordinateFields(
        title: String,
        latitude: Binding<String>,
        longitude: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            SiteTextField(title: "Latitude", placeholder: "-8.128667", text: latitude)
            SiteTextField(title: "Longitude", placeholder: "114.660816", text: longitude)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var mapPreview: some View {
        if let start = parsedStartCoordinate, let end = parsedEndCoordinate {
            MapReader { proxy in
                ZStack(alignment: .topLeading) {
                    Map(interactionModes: selectedMapPoint == nil ? .all : []) {
                        MapCircle(
                            center: SiteCoverageGeometry.center(between: start, and: end),
                            radius: max(SiteCoverageGeometry.radius(between: start, and: end), 1)
                        )
                        .foregroundStyle(Color(hex: "17C3B2").opacity(0.16))
                        .stroke(Color(hex: "17C3B2"), lineWidth: 3)

                        Annotation("", coordinate: start) {
                            mapMarker(
                                title: "Start",
                                systemImage: "s.circle.fill",
                                isSelected: selectedMapPoint == .start
                            )
                            .highPriorityGesture(
                                TapGesture(count: 2)
                                    .onEnded { selectedMapPoint = .start }
                            )
                        }

                        Annotation("", coordinate: end) {
                            mapMarker(
                                title: "Finish",
                                systemImage: "f.circle.fill",
                                isSelected: selectedMapPoint == .finish
                            )
                            .highPriorityGesture(
                                TapGesture(count: 2)
                                    .onEnded { selectedMapPoint = .finish }
                            )
                        }
                    }
                    .mapStyle(.standard)

                    if let selectedMapPoint {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(placementGesture(using: proxy))

                        Label(
                            "Move \(selectedMapPoint.title), then release to confirm",
                            systemImage: "cursorarrow.motionlines"
                        )
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(.regularMaterial, in: Capsule())
                        .padding(10)
                        .allowsHitTesting(false)
                    } else {
                        Label("Double-click Start or Finish to move it", systemImage: "cursorarrow.click.2")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(.regularMaterial, in: Capsule())
                            .padding(10)
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(.named(mapCoordinateSpace))
            }
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 28))
                        Text("Enter valid Start and Finish coordinates to preview the Site")
                        .font(.callout)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func mapMarker(title: String, systemImage: String, isSelected: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: isSelected ? 30 : 25, weight: .semibold))
                .foregroundStyle(.white, isSelected ? Color.accentColor : Color(hex: "29CBB5"))
                .shadow(color: isSelected ? Color.accentColor.opacity(0.7) : .black.opacity(0.25), radius: isSelected ? 7 : 2, y: 1)

            Text(title)
                .font(.caption2.bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: Capsule())
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private func placementGesture(using proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(mapCoordinateSpace))
            .onChanged { value in
                guard let coordinate = proxy.convert(value.location, from: .named(mapCoordinateSpace)) else {
                    return
                }

                switch selectedMapPoint {
                case nil:
                    break
                case .some(.start):
                    updateStartCoordinate(coordinate)
                case .some(.finish):
                    updateEndCoordinate(coordinate)
                }
            }
            .onEnded { _ in
                selectedMapPoint = nil
            }
    }

    private func updateStartCoordinate(_ coordinate: CLLocationCoordinate2D) {
        startLatitude = formattedCoordinate(coordinate.latitude)
        startLongitude = formattedCoordinate(coordinate.longitude)
    }

    private func updateEndCoordinate(_ coordinate: CLLocationCoordinate2D) {
        endLatitude = formattedCoordinate(coordinate.latitude)
        endLongitude = formattedCoordinate(coordinate.longitude)
    }

    private func formattedCoordinate(_ value: CLLocationDegrees) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(6))
                .grouping(.never)
        )
    }

    private func coordinate(latitude: String, longitude: String) -> CLLocationCoordinate2D? {
        guard
            let latitude = Double(latitude),
            let longitude = Double(longitude),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func submit() {
        guard let start = parsedStartCoordinate, let end = parsedEndCoordinate, isValid else { return }
        onSubmit(trimmedName, start.latitude, start.longitude, end.latitude, end.longitude)
    }
}

private enum SiteFormMapPoint: Hashable {
    case start
    case finish

    var title: String {
        switch self {
        case .start: "Start"
        case .finish: "Finish"
        }
    }
}

private struct SiteTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
        }
    }
}

struct SitePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct SiteSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(.secondary.opacity(configuration.isPressed ? 0.16 : 0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ZStack {
        Color(nsColor: .windowBackgroundColor)
        SiteFormOverlay(onCancel: {}, onSubmit: { _, _, _, _, _ in })
    }
    .frame(width: 900, height: 700)
}
