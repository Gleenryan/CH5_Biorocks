import Combine
import Foundation
import SwiftData

@MainActor
final class DetectionStore: ObservableObject {
    @Published var log: [PipelineLogLine] = []
    @Published var liveHydrophones: [LiveHydrophoneStatus] = []
    @Published var lastScorecard: SimScorecard?
    @Published var classifierReady = false
    @Published var classifierError: String?
    @Published var serverReady = false
    @Published var serverError: String?
    @Published var lastHealth: HealthScoreResult?
    @Published var envelopes: [String: [Double]] = [:]
    @Published var listeningHydrophoneID: String?
    @Published var hasClip: [String: Bool] = [:]

    weak var modelContext: ModelContext?
    private let envelopeMaxPoints = 192

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func appendLog(_ line: PipelineLogLine) {
        log.insert(line, at: 0)
        if log.count > 400 {
            log.removeLast(log.count - 400)
        }
    }

    func upsertHydrophone(_ status: LiveHydrophoneStatus) {
        let previous = liveHydrophones.first { $0.id == status.id }
        if let index = liveHydrophones.firstIndex(where: { $0.id == status.id }) {
            liveHydrophones[index] = status
        } else {
            liveHydrophones.insert(status, at: 0)
        }
        if status.connected && (previous == nil || previous?.connected == false) {
            registerDetectedHydrophone(status)
        }
        if !status.envelopeBins.isEmpty {
            appendEnvelope(id: status.id, bins: status.envelopeBins)
        }
        if status.samplesReceived > 0 {
            hasClip[status.id] = true
        }
    }

    func appendEnvelope(id: String, bins: [Double]) {
        var envelope = envelopes[id] ?? []
        envelope.append(contentsOf: bins)
        if envelope.count > envelopeMaxPoints {
            envelope.removeFirst(envelope.count - envelopeMaxPoints)
        }
        envelopes[id] = envelope
    }

    func envelope(for id: String) -> [Double] {
        envelopes[id] ?? []
    }

    func toggleListen(id: String) {
        listeningHydrophoneID = listeningHydrophoneID == id ? nil : id
    }

    /// Creates (or updates) a Site + hydrophone so the simulator stream shows up
    /// in Sensors, the map, and the sidebar like any other detected input.
    func registerDetectedHydrophone(_ status: LiveHydrophoneStatus) {
        guard let modelContext else { return }

        let sites = (try? modelContext.fetch(FetchDescriptor<Site>())) ?? []
        let site: Site
        if let existing = sites.first(where: {
            $0.name.localizedCaseInsensitiveCompare(status.siteName) == .orderedSame
        }) {
            site = existing
        } else {
            site = Site(
                name: status.siteName,
                startLatitude: status.latitude.map { $0 - 0.003 } ?? -8.1287,
                startLongitude: status.longitude.map { $0 - 0.004 } ?? 114.6608,
                endLatitude: status.latitude.map { $0 + 0.003 } ?? -8.1322,
                endLongitude: status.longitude.map { $0 + 0.006 } ?? 114.6715
            )
            modelContext.insert(site)
        }

        let deviceID = status.simulatorDeviceID
        let existing = site.hydrophones.first {
            $0.microphoneDeviceID == deviceID
                || $0.name.localizedCaseInsensitiveCompare(status.name) == .orderedSame
        }

        let index = site.hydrophones.count
        let latitude = status.latitude
            ?? (site.startLatitude + site.endLatitude) / 2
            + Double(index) * 0.0004
        let longitude = status.longitude
            ?? (site.startLongitude + site.endLongitude) / 2
            + Double(index) * 0.00035

        if let existing {
            existing.name = status.name
            existing.microphoneDeviceID = deviceID
            existing.microphoneDeviceName = "Detected · Python simulator · \(status.scenarioName)"
            if let lat = status.latitude { existing.latitude = lat }
            if let lon = status.longitude { existing.longitude = lon }
        } else {
            let hydrophone = CustomLocation(
                id: UUID(uuidString: status.id) ?? UUID(),
                name: status.name,
                latitude: latitude,
                longitude: longitude,
                microphoneDeviceID: deviceID,
                microphoneDeviceName: "Detected · Python simulator · \(status.scenarioName)",
                site: site
            )
            modelContext.insert(hydrophone)
            site.hydrophones.append(hydrophone)
        }

        try? modelContext.save()
        appendLog(
            PipelineLogLine(
                hydrophoneName: status.name,
                stage: "Detect",
                detail: "Registered hydrophone on \(site.name)"
            )
        )
    }

    func markDisconnected(id: String) {
        if let index = liveHydrophones.firstIndex(where: { $0.id == id }) {
            liveHydrophones[index].connected = false
        }
    }

    func persist(_ detection: PromotedDetection) {
        let event = BlastDetectionEvent(
            siteName: detection.siteName,
            hydrophoneName: detection.hydrophoneName,
            hydrophoneId: detection.hydrophoneId,
            source: detection.source,
            scenarioId: detection.scenarioId,
            onsetTime: detection.onsetTime,
            pBlast: detection.pBlast,
            topClass: detection.topClass,
            topConfidence: detection.topConfidence,
            narrative: detection.narrative.displayText,
            narrativeSource: detection.narrative.source,
            severity: detection.narrative.severity,
            recommendedAction: detection.narrative.recommendedAction
        )
        modelContext?.insert(event)
        try? modelContext?.save()
    }

    func persist(health: HealthScoreResult, siteName: String, hydrophoneName: String, narrative: HealthNarrative) {
        lastHealth = health
        let record = HealthSnapshotRecord(
            siteName: siteName,
            hydrophoneName: hydrophoneName,
            healthScore: health.healthScore,
            healthClass: health.healthClass,
            aci: health.indices.aci,
            adi: health.indices.adi,
            aei: health.indices.aei,
            ndsi: health.indices.ndsi,
            lowFreqSPL_dB: health.indices.lowFreqSPL_dB,
            snapRatePerMin: health.indices.snapRatePerMin,
            biophonyRatio: health.indices.biophonyRatio,
            anthrophonyRatio: health.indices.anthrophonyRatio,
            blastEventCountLastHour: health.blastEventCountLastHour,
            topDrivers: health.topDrivers.map { "\($0.feature):\($0.contribution)" }.joined(separator: ","),
            narrative: "\(narrative.headline)\n\(narrative.narrative)",
            narrativeSource: narrative.source,
            note: health.note
        )
        modelContext?.insert(record)
        try? modelContext?.save()
    }

    func eventsLastHour(siteName: String? = nil) -> Int {
        guard let modelContext else { return 0 }
        let cutoff = Date().addingTimeInterval(-3600)
        var descriptor = FetchDescriptor<BlastDetectionEvent>(
            predicate: #Predicate { $0.onsetTime >= cutoff }
        )
        descriptor.fetchLimit = 500
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        if let siteName {
            return rows.filter { $0.siteName == siteName }.count
        }
        return rows.count
    }
}
