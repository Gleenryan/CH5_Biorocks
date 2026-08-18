import Foundation
import SwiftData

/// Development-only sample content requested for the current UI prototype.
/// Names make the demo nature explicit and no hardware microphone is assigned.
enum DemoSiteSeeder {
    static let seededSiteNames = ["Nusa Penida (Demo)", "Amed (Demo)"]

    static func seedMissingSites(
        into modelContext: ModelContext,
        existingSites: [Site]
    ) throws {
        let existingNames = Set(existingSites.map(\.name))

        if !existingNames.contains(seededSiteNames[0]) {
            insertNusaPenidaDemo(into: modelContext)
        }

        if !existingNames.contains(seededSiteNames[1]) {
            insertAmedDemo(into: modelContext)
        }

        try modelContext.save()
    }

    private static func insertNusaPenidaDemo(into modelContext: ModelContext) {
        let site = Site(
            name: seededSiteNames[0],
            startLatitude: -8.7270,
            startLongitude: 115.5440,
            endLatitude: -8.7205,
            endLongitude: 115.5530
        )

        attachDemoHydrophones(
            to: site,
            coordinates: [
                (-8.7258, 115.5452),
                (-8.7239, 115.5484),
                (-8.7218, 115.5512)
            ],
            modelContext: modelContext
        )
    }

    private static func insertAmedDemo(into modelContext: ModelContext) {
        let site = Site(
            name: seededSiteNames[1],
            startLatitude: -8.3405,
            startLongitude: 115.6635,
            endLatitude: -8.3340,
            endLongitude: 115.6720
        )

        attachDemoHydrophones(
            to: site,
            coordinates: [
                (-8.3393, 115.6649),
                (-8.3371, 115.6678),
                (-8.3351, 115.6704)
            ],
            modelContext: modelContext
        )
    }

    private static func attachDemoHydrophones(
        to site: Site,
        coordinates: [(latitude: Double, longitude: Double)],
        modelContext: ModelContext
    ) {
        modelContext.insert(site)

        for (index, coordinate) in coordinates.enumerated() {
            let hydrophone = CustomLocation(
                name: "Demo Hydrophone \(index + 1)",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            site.hydrophones.append(hydrophone)
            modelContext.insert(hydrophone)
        }
    }
}
