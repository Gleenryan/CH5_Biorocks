import SwiftUI
import MapKit

struct SiteMapView: View {
    let site: Site
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            MapCircle(
                center: site.coverageCenterCoordinate,
                radius: max(site.coverageRadiusMeters, 1)
            )
            .foregroundStyle(Color(hex: "17C3B2").opacity(0.16))
            .stroke(Color(hex: "17C3B2"), lineWidth: 3)

            Marker("Center", systemImage: "scope", coordinate: site.coverageCenterCoordinate)
                .tint(Color(hex: "1DB7D9"))

            Marker("Start", systemImage: "circle.fill", coordinate: site.startCoordinate)
                .tint(Color(hex: "29CBB5"))

            Marker("Finish", systemImage: "circle.fill", coordinate: site.endCoordinate)
                .tint(Color(hex: "29CBB5"))

            ForEach(site.hydrophones) { hydrophone in
                Marker(hydrophone.name, systemImage: "mic.fill", coordinate: hydrophone.coordinate)
                    .tint(.orange)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
        }
        .onChange(of: site.id) {
            cameraPosition = .automatic
        }
    }
}
