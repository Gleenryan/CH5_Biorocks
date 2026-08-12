import Foundation
import SwiftData
import CoreLocation

@Model
class CustomLocation: Identifiable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    
    // Computed property for MapKit convenience
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
