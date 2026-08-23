import Foundation
import SwiftData

@Model
final class BlastDetectionEvent {
    var id: UUID
    var siteName: String
    var hydrophoneName: String
    var hydrophoneId: String
    var source: String
    var scenarioId: String
    var onsetTime: Date
    var pBlast: Double
    var topClass: String
    var topConfidence: Double
    var narrative: String
    var narrativeSource: String
    var severity: String
    var recommendedAction: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        siteName: String,
        hydrophoneName: String,
        hydrophoneId: String,
        source: String,
        scenarioId: String,
        onsetTime: Date,
        pBlast: Double,
        topClass: String,
        topConfidence: Double,
        narrative: String,
        narrativeSource: String,
        severity: String,
        recommendedAction: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.siteName = siteName
        self.hydrophoneName = hydrophoneName
        self.hydrophoneId = hydrophoneId
        self.source = source
        self.scenarioId = scenarioId
        self.onsetTime = onsetTime
        self.pBlast = pBlast
        self.topClass = topClass
        self.topConfidence = topConfidence
        self.narrative = narrative
        self.narrativeSource = narrativeSource
        self.severity = severity
        self.recommendedAction = recommendedAction
        self.createdAt = createdAt
    }
}
