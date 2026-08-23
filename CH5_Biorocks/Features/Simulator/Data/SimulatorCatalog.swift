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
    struct Spec {
        let siteName: String
        let hydrophoneName: String
        let latitude: Double
        let longitude: Double
        let scenarioName: String
        let injectBlast: Bool
    }

    static let fleet: [Spec] = [
        Spec(
            siteName: "Simulator Reef",
            hydrophoneName: "Sim Hydro 1",
            latitude: -8.1287,
            longitude: 114.6608,
            scenarioName: "blast_in_ambient",
            injectBlast: true
        ),
        Spec(
            siteName: "Simulator Amed",
            hydrophoneName: "Sim Hydro Amed",
            latitude: -8.3378,
            longitude: 115.6594,
            scenarioName: "ambient",
            injectBlast: false
        ),
        Spec(
            siteName: "Simulator Nusa Penida",
            hydrophoneName: "Sim Hydro Penida",
            latitude: -8.7278,
            longitude: 115.5442,
            scenarioName: "boat_pass",
            injectBlast: false
        ),
        Spec(
            siteName: "Simulator Tulamben",
            hydrophoneName: "Sim Hydro Tulamben",
            latitude: -8.2774,
            longitude: 115.4965,
            scenarioName: "ambient",
            injectBlast: false
        )
    ]

    @MainActor
    static func bootstrap(modelContext: ModelContext) {
        purgeDemos(modelContext: modelContext)
        ensureFleet(modelContext: modelContext)
        ensureBlastAlert(modelContext: modelContext)
        try? modelContext.save()
    }

    @MainActor
    static func purgeDemos(modelContext: ModelContext) {
        let sites = (try? modelContext.fetch(FetchDescriptor<Site>())) ?? []
        for site in sites where isDemoName(site.name) || isLeftoverEmptyPemuteran(site) {
            modelContext.delete(site)
        }

        let events = (try? modelContext.fetch(FetchDescriptor<BlastDetectionEvent>())) ?? []
        for event in events where isDemoName(event.siteName) {
            modelContext.delete(event)
        }

        let snapshots = (try? modelContext.fetch(FetchDescriptor<HealthSnapshotRecord>())) ?? []
        for snapshot in snapshots where isDemoName(snapshot.siteName) {
            modelContext.delete(snapshot)
        }
    }

    @MainActor
    static func ensureFleet(modelContext: ModelContext) {
        let sites = (try? modelContext.fetch(FetchDescriptor<Site>())) ?? []
        for spec in fleet {
            let site = sites.first { $0.name.localizedCaseInsensitiveCompare(spec.siteName) == .orderedSame }
                ?? {
                    let created = Site(
                        name: spec.siteName,
                        startLatitude: spec.latitude - 0.003,
                        startLongitude: spec.longitude - 0.004,
                        endLatitude: spec.latitude + 0.003,
                        endLongitude: spec.longitude + 0.006
                    )
                    modelContext.insert(created)
                    return created
                }()

            let hydroID = UUIDV5.dns(spec.hydrophoneName)
            let deviceID = "sim://\(hydroID.uuidString.lowercased())"
            let existing = site.hydrophones.first {
                $0.microphoneDeviceID == deviceID
                    || $0.name.localizedCaseInsensitiveCompare(spec.hydrophoneName) == .orderedSame
            }
            if let existing {
                existing.name = spec.hydrophoneName
                existing.latitude = spec.latitude
                existing.longitude = spec.longitude
                existing.microphoneDeviceID = deviceID
                existing.microphoneDeviceName = "Python simulator · \(spec.scenarioName)"
            } else {
                let hydrophone = CustomLocation(
                    id: hydroID,
                    name: spec.hydrophoneName,
                    latitude: spec.latitude,
                    longitude: spec.longitude,
                    microphoneDeviceID: deviceID,
                    microphoneDeviceName: "Python simulator · \(spec.scenarioName)",
                    site: site
                )
                modelContext.insert(hydrophone)
                site.hydrophones.append(hydrophone)
            }
        }
    }

    @MainActor
    static func ensureBlastAlert(modelContext: ModelContext) {
        guard let spec = fleet.first(where: \.injectBlast) else { return }
        let hydroID = UUIDV5.dns(spec.hydrophoneName).uuidString.lowercased()
        let events = (try? modelContext.fetch(FetchDescriptor<BlastDetectionEvent>())) ?? []
        if events.contains(where: { $0.hydrophoneId.lowercased() == hydroID }) {
            return
        }

        let narrative = FoundationModelNarrator.templatedAlert(
            site: spec.siteName,
            time: Date().formatted(date: .omitted, time: .shortened),
            pBlast: 0.882,
            alerted: true
        )
        let event = BlastDetectionEvent(
            siteName: spec.siteName,
            hydrophoneName: spec.hydrophoneName,
            hydrophoneId: hydroID,
            source: "simulator",
            scenarioId: spec.scenarioName,
            onsetTime: Date().addingTimeInterval(-12),
            pBlast: 0.882,
            topClass: "blast",
            topConfidence: 0.882,
            narrative: narrative.displayText,
            narrativeSource: narrative.source,
            severity: "medium",
            recommendedAction: narrative.recommendedAction
        )
        modelContext.insert(event)
    }

    private static func isDemoName(_ name: String) -> Bool {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return folded.contains("(demo)")
            || folded.hasSuffix(" demo")
    }

    private static func isLeftoverEmptyPemuteran(_ site: Site) -> Bool {
        site.name.localizedCaseInsensitiveCompare("Pemuteran Reef Site") == .orderedSame
            && site.hydrophones.isEmpty
    }
}
