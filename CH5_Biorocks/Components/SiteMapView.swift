import SwiftUI
import MapKit

struct SiteMapView: View {
    let site: Site
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            Marker("Start", systemImage: "flag.fill", coordinate: site.startCoordinate)
                .tint(Color(hex: "1DB7D9"))

            Marker("End", systemImage: "flag.checkered", coordinate: site.endCoordinate)
                .tint(Color(hex: "29CBB5"))

            MapPolyline(coordinates: [site.startCoordinate, site.endCoordinate])
                .stroke(Color(hex: "17C3B2"), style: StrokeStyle(lineWidth: 4, lineCap: .round))

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
