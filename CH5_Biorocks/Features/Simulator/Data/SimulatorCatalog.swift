import CryptoKit
import Foundation
import SwiftData

enum UUIDV5 {
    static let dnsNamespace = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!

    static func dns(_ name: String) -> UUID {
        make(namespace: dnsNamespace, name: name)
    }

    static func make(namespace: UUID, name: String) -> UUID {
        var bytes = [UInt8]()
        bytes.append(contentsOf: withUnsafeBytes(of: namespace.uuid) { Array($0) })
        bytes.append(contentsOf: Array(name.utf8))
        let digest = Insecure.SHA1.hash(data: Data(bytes))
        var raw = Array(digest.prefix(16))
        raw[6] = (raw[6] & 0x0F) | 0x50
        raw[8] = (raw[8] & 0x3F) | 0x80
        return UUID(uuid: (
            raw[0], raw[1], raw[2], raw[3],
            raw[4], raw[5], raw[6], raw[7],
            raw[8], raw[9], raw[10], raw[11],
            raw[12], raw[13], raw[14], raw[15]
        ))
    }
}

enum SimulatorCatalog {
    /// Single site; hydrophones around this location.
    /// Blast vs field audio is decided by reef_pipeline at stream time (not hardcoded here).
    static let siteName = "Indonesia N1"
    static let siteLatitude = -8.1287
    static let siteLongitude = 114.6608

    struct Spec {
        let siteName: String
        let hydrophoneName: String
        let latitude: Double
        let longitude: Double
    }

    static let fleet: [Spec] = [
        Spec(siteName: siteName, hydrophoneName: "Hydrophone 1", latitude: -8.1287, longitude: 114.6608),
        Spec(siteName: siteName, hydrophoneName: "Hydrophone 2", latitude: -8.1264, longitude: 114.6636),
        Spec(siteName: siteName, hydrophoneName: "Hydrophone 3", latitude: -8.1312, longitude: 114.6582),
        Spec(siteName: siteName, hydrophoneName: "Hydrophone 4", latitude: -8.1271, longitude: 114.6574),
    ]

    @MainActor
    static func bootstrap(modelContext: ModelContext) {
        purgeExtraSites(modelContext: modelContext)
        ensureFleet(modelContext: modelContext)
        ensureSampleAlerts(modelContext: modelContext)
        try? modelContext.save()
    }

    /// Call when starting a new simulator stream so Bomb Alerts reflect this run only.
    @MainActor
    static func clearSiteAlerts(modelContext: ModelContext) {
        let events = (try? modelContext.fetch(FetchDescriptor<BlastDetectionEvent>())) ?? []
        for event in events {
            modelContext.delete(event)
        }
        try? modelContext.save()
    }

    @MainActor
    static func purgeExtraSites(modelContext: ModelContext) {
        let sites = (try? modelContext.fetch(FetchDescriptor<Site>())) ?? []
        for site in sites where site.name.localizedCaseInsensitiveCompare(siteName) != .orderedSame {
            modelContext.delete(site)
        }

        let events = (try? modelContext.fetch(FetchDescriptor<BlastDetectionEvent>())) ?? []
        for event in events where event.siteName.localizedCaseInsensitiveCompare(siteName) != .orderedSame {
            modelContext.delete(event)
        }

        let snapshots = (try? modelContext.fetch(FetchDescriptor<HealthSnapshotRecord>())) ?? []
        for snapshot in snapshots where snapshot.siteName.localizedCaseInsensitiveCompare(siteName) != .orderedSame {
            modelContext.delete(snapshot)
        }
    }

    @MainActor
    static func ensureSampleAlerts(modelContext: ModelContext) {
        let events = (try? modelContext.fetch(FetchDescriptor<BlastDetectionEvent>())) ?? []
        guard events.isEmpty else { return }

        let now = Date()
        let sampleAlerts = [
            BlastDetectionEvent(
                siteName: siteName,
                hydrophoneName: "Hydrophone 1",
                hydrophoneId: "sim://\(UUIDV5.dns("Hydrophone 1").uuidString.lowercased())",
                source: "reef_pipeline",
                scenarioId: "blast_in_ambient",
                onsetTime: now.addingTimeInterval(-3600 * 2),
                pBlast: 0.94,
                topClass: "blast",
                topConfidence: 0.94,
                narrative: "Suspected Blast Event\nHigh-energy impulsive detonation signature detected with sharp rise time and dominant low-frequency shockwave.",
                narrativeSource: "Core ML Classifier",
                severity: "High",
                recommendedAction: "Dispatch local marine patrol for inspection and deploy emergency acoustic surveillance protocol.",
                createdAt: now.addingTimeInterval(-3600 * 2),
                domainScope: "indonesia_hydromoth"
            ),
            BlastDetectionEvent(
                siteName: siteName,
                hydrophoneName: "Hydrophone 2",
                hydrophoneId: "sim://\(UUIDV5.dns("Hydrophone 2").uuidString.lowercased())",
                source: "reef_pipeline",
                scenarioId: "boat_pass",
                onsetTime: now.addingTimeInterval(-3600 * 6),
                pBlast: 0.28,
                topClass: "boat_engine",
                topConfidence: 0.82,
                narrative: "High-Frequency Vessel Intrusion\nProlonged low-to-mid frequency propulsion resonance detected crossing perimeter boundary.",
                narrativeSource: "Core ML Classifier",
                severity: "Medium",
                recommendedAction: "Monitor vessel trajectory on marine tracker and record baseline soundscape impact.",
                createdAt: now.addingTimeInterval(-3600 * 6),
                domainScope: "indonesia_hydromoth"
            ),
            BlastDetectionEvent(
                siteName: siteName,
                hydrophoneName: "Hydrophone 3",
                hydrophoneId: "sim://\(UUIDV5.dns("Hydrophone 3").uuidString.lowercased())",
                source: "reef_pipeline",
                scenarioId: "ambient",
                onsetTime: now.addingTimeInterval(-3600 * 18),
                pBlast: 0.08,
                topClass: "biophony_shift",
                topConfidence: 0.75,
                narrative: "Biophony Activity Variance\nTemporary decrease in snapping shrimp pulse frequency and biological acoustic diversity.",
                narrativeSource: "Acoustic Index Monitor",
                severity: "Low",
                recommendedAction: "Review subsequent 6-hour acoustic health snapshot trend for recovery.",
                createdAt: now.addingTimeInterval(-3600 * 18),
                domainScope: "indonesia_hydromoth"
            )
        ]

        for alert in sampleAlerts {
            modelContext.insert(alert)
        }
    }

    @MainActor
    static func ensureFleet(modelContext: ModelContext) {
        let sites = (try? modelContext.fetch(FetchDescriptor<Site>())) ?? []
        let lats = fleet.map(\.latitude)
        let lons = fleet.map(\.longitude)
        let pad = 0.004
        let site = sites.first { $0.name.localizedCaseInsensitiveCompare(siteName) == .orderedSame }
            ?? {
                let created = Site(
                    name: siteName,
                    startLatitude: (lats.min() ?? siteLatitude) - pad,
                    startLongitude: (lons.min() ?? siteLongitude) - pad,
                    endLatitude: (lats.max() ?? siteLatitude) + pad,
                    endLongitude: (lons.max() ?? siteLongitude) + pad
                )
                modelContext.insert(created)
                return created
            }()

        site.startLatitude = (lats.min() ?? siteLatitude) - pad
        site.startLongitude = (lons.min() ?? siteLongitude) - pad
        site.endLatitude = (lats.max() ?? siteLatitude) + pad
        site.endLongitude = (lons.max() ?? siteLongitude) + pad

        let wantedNames = Set(fleet.map { $0.hydrophoneName.lowercased() })
        for hydro in site.hydrophones where !wantedNames.contains(hydro.name.lowercased()) {
            modelContext.delete(hydro)
        }

        for spec in fleet {
            let hydroID = UUIDV5.dns(spec.hydrophoneName)
            let deviceID = "sim://\(hydroID.uuidString.lowercased())"
            let existing = site.hydrophones.first {
                $0.id == hydroID
                    || $0.microphoneDeviceID == deviceID
                    || $0.name.localizedCaseInsensitiveCompare(spec.hydrophoneName) == .orderedSame
            }
            if let existing {
                existing.name = spec.hydrophoneName
                existing.latitude = spec.latitude
                existing.longitude = spec.longitude
                existing.microphoneDeviceID = deviceID
                existing.microphoneDeviceName = "reef_pipeline"
            } else {
                let hydrophone = CustomLocation(
                    id: hydroID,
                    name: spec.hydrophoneName,
                    latitude: spec.latitude,
                    longitude: spec.longitude,
                    microphoneDeviceID: deviceID,
                    microphoneDeviceName: "reef_pipeline",
                    site: site
                )
                modelContext.insert(hydrophone)
                site.hydrophones.append(hydrophone)
            }
        }
    }
}
