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

    /// The geographic midpoint between the two saved boundary points.
    var coverageCenterCoordinate: CLLocationCoordinate2D {
        SiteCoverageGeometry.center(between: startCoordinate, and: endCoordinate)
    }

    /// Half the distance between the two saved boundary points.
    var coverageRadiusMeters: CLLocationDistance {
        SiteCoverageGeometry.radius(between: startCoordinate, and: endCoordinate)
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

enum SiteCoverageGeometry {
    static func center(
        between first: CLLocationCoordinate2D,
        and second: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let latitude1 = first.latitude * .pi / 180
        let longitude1 = first.longitude * .pi / 180
        let latitude2 = second.latitude * .pi / 180
        let longitude2 = second.longitude * .pi / 180
        let longitudeDelta = longitude2 - longitude1

        let projectedX = cos(latitude2) * cos(longitudeDelta)
        let projectedY = cos(latitude2) * sin(longitudeDelta)
        let combinedX = cos(latitude1) + projectedX
        let combinedZ = sin(latitude1) + sin(latitude2)

        guard abs(combinedX) + abs(projectedY) + abs(combinedZ) > 1e-12 else {
            return first
        }

        let centerLatitude = atan2(
            combinedZ,
            hypot(combinedX, projectedY)
        )
        let centerLongitude = longitude1 + atan2(projectedY, combinedX)
        let longitudeDegrees = centerLongitude * 180 / .pi
        let normalizedLongitude = (longitudeDegrees + 540)
            .truncatingRemainder(dividingBy: 360) - 180

        return CLLocationCoordinate2D(
            latitude: centerLatitude * 180 / .pi,
            longitude: normalizedLongitude
        )
    }

    static func radius(
        between first: CLLocationCoordinate2D,
        and second: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let firstLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let secondLocation = CLLocation(latitude: second.latitude, longitude: second.longitude)
        return firstLocation.distance(from: secondLocation) / 2
    }
}
