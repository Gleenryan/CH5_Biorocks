import Foundation
import SwiftData
import CoreLocation

@Model
final class Site: Identifiable {
    var id: UUID
    var name: String
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CustomLocation.site)
    var hydrophones: [CustomLocation]

    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }

    var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.createdAt = createdAt
        self.hydrophones = []
    }
}
