import Foundation

nonisolated struct PipelineLogLine: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let hydrophoneName: String
    let stage: String
    let detail: String

    init(id: UUID = UUID(), timestamp: Date = .now, hydrophoneName: String, stage: String, detail: String) {
        self.id = id
        self.timestamp = timestamp
        self.hydrophoneName = hydrophoneName
        self.stage = stage
        self.detail = detail
    }
}

nonisolated struct GroundTruthWire: Sendable, Identifiable, Codable {
    var id: String
    var tOnsetSeconds: Double
    var tOffsetSeconds: Double?
    var label: String
    var expectedAlert: Bool
    var sourceClipId: String
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, tOnsetSeconds, tOffsetSeconds, label, expectedAlert, sourceClipId, notes
    }
}

nonisolated struct HydrophoneHello: Sendable {
    var hydrophoneId: String
    var hydrophoneName: String
    var siteName: String
    var sampleRate: Double
    var channels: Int
    var scenarioId: String
    var scenarioName: String
    var source: String
    var construction: String
    var durationSeconds: Double
    var latitude: Double?
    var longitude: Double?
    var events: [GroundTruthWire]
}

nonisolated struct LiveHydrophoneStatus: Identifiable, Sendable {
    var id: String
    var name: String
    var siteName: String
    var scenarioName: String
    var connected: Bool
    var samplesReceived: Int
    var lastRMS: Double
    var connectedAt: Date
    var latitude: Double?
    var longitude: Double?
    var envelopeBins: [Double] = []

    var simulatorDeviceID: String { "sim://\(id)" }
}

nonisolated struct SimScorecard: Sendable {
    var scenarioId: String
    var tp: Int
    var fp: Int
    var fn: Int
    var model1Misses: Int
    var debounceDrops: Int

    var recall: Double {
        let d = tp + fn
        return d == 0 ? 1 : Double(tp) / Double(d)
    }

    var precision: Double {
        let d = tp + fp
        return d == 0 ? 1 : Double(tp) / Double(d)
    }
}

nonisolated struct PromotedDetection: Sendable {
    var hydrophoneId: String
    var hydrophoneName: String
    var siteName: String
    var source: String
    var scenarioId: String
    var onsetTime: Date
    var streamTime: TimeInterval
    var pBlast: Double
    var topClass: String
    var topConfidence: Double
    var probabilities: [String: Double]
    var energyRatio: Double
    var bandEnergyDb: Double
    var narrative: AlertNarrative
}
