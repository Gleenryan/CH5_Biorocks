import SwiftUI
import MapKit

struct SiteFormOverlay: View {
    var onCancel: () -> Void
    var onSubmit: (String, Double, Double, Double, Double) -> Void

    @State private var name = "Pemuteran Reef Site"
    @State private var startLatitude = "-8.128667"
    @State private var startLongitude = "114.660816"
    @State private var endLatitude = "-8.132200"
    @State private var endLongitude = "114.671500"

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
                    title: "START COORDINATE",
                    latitude: $startLatitude,
                    longitude: $startLongitude
                )

                coordinateFields(
                    title: "END COORDINATE",
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
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
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
            Map {
                Marker("Start", systemImage: "flag.fill", coordinate: start)
                    .tint(Color(hex: "1DB7D9"))
                Marker("End", systemImage: "flag.checkered", coordinate: end)
                    .tint(Color(hex: "29CBB5"))
                MapPolyline(coordinates: [start, end])
                    .stroke(Color(hex: "17C3B2"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            .mapStyle(.standard)
            .id("\(start.latitude)-\(start.longitude)-\(end.latitude)-\(end.longitude)")
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 28))
                    Text("Enter valid start and end coordinates to preview the Site")
                        .font(.callout)
                }
                .foregroundStyle(.secondary)
            }
        }
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
