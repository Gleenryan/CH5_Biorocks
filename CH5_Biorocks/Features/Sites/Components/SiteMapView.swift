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
