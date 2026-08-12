import SwiftUI
import MapKit
import SwiftData

struct DynamicMapView: View {
    var locations: [CustomLocation]
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        Map(position: $position) {
            ForEach(locations) { location in
                Marker(location.name, coordinate: location.coordinate)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
            MapUserLocationButton()
        }
    }
}
