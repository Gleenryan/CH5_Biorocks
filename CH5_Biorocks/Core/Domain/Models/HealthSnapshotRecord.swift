import Foundation
import SwiftData

@Model
final class HealthSnapshotRecord {
    var id: UUID
    var siteName: String
    var hydrophoneName: String
    var windowStart: Date
    var healthScore: Double
    var healthClass: String
    var aci: Double
    var adi: Double
    var aei: Double
    var ndsi: Double
    var lowFreqSPL_dB: Double
    var snapRatePerMin: Double
    var biophonyRatio: Double
    var anthrophonyRatio: Double
    var blastEventCountLastHour: Int
    var topDrivers: String
    var narrative: String
    var narrativeSource: String
    var note: String

    init(
        id: UUID = UUID(),
        siteName: String,
        hydrophoneName: String,
        windowStart: Date = .now,
        healthScore: Double,
        healthClass: String,
        aci: Double,
        adi: Double,
        aei: Double,
        ndsi: Double,
        lowFreqSPL_dB: Double,
        snapRatePerMin: Double,
        biophonyRatio: Double,
        anthrophonyRatio: Double,
        blastEventCountLastHour: Int,
        topDrivers: String,
        narrative: String,
        narrativeSource: String,
        note: String
    ) {
        self.id = id
        self.siteName = siteName
        self.hydrophoneName = hydrophoneName
        self.windowStart = windowStart
        self.healthScore = healthScore
        self.healthClass = healthClass
        self.aci = aci
        self.adi = adi
        self.aei = aei
        self.ndsi = ndsi
        self.lowFreqSPL_dB = lowFreqSPL_dB
        self.snapRatePerMin = snapRatePerMin
        self.biophonyRatio = biophonyRatio
        self.anthrophonyRatio = anthrophonyRatio
        self.blastEventCountLastHour = blastEventCountLastHour
        self.topDrivers = topDrivers
        self.narrative = narrative
        self.narrativeSource = narrativeSource
        self.note = note
    }
}
