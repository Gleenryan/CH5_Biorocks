import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

nonisolated struct AlertNarrative: Sendable {
    var headline: String
    var severity: String
    var explanation: String
    var recommendedAction: String
    var source: String

    var displayText: String {
        "\(headline)\nseverity: \(severity)\n\(explanation)\naction: \(recommendedAction)"
    }
}

nonisolated struct HealthNarrative: Sendable {
    var headline: String
    var narrative: String
    var trendDirection: String
    var topDrivers: [String]
    var source: String
}

enum FoundationModelNarrator {
    static var isAvailable: Bool {
#if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
#endif
        return false
    }

    static func templatedAlert(
        site: String,
        time: String,
        pBlast: Double,
        alerted: Bool
    ) -> AlertNarrative {
        let pct = Int((pBlast * 100).rounded())
        if alerted {
            return AlertNarrative(
                headline: "Possible blast at \(site)",
                severity: pBlast >= 0.9 ? "high" : "medium",
                explanation: "Possible blast detected at \(site) at \(time), confidence \(pct)%.",
                recommendedAction: "Review the hydrophone clip and confirm on site if safe to do so.",
                source: "template"
            )
        }
        return AlertNarrative(
            headline: "No blast alert",
            severity: "low",
            explanation: "No blast alert at \(site) at \(time) (score \(pct)% below threshold).",
            recommendedAction: "No action required.",
            source: "template"
        )
    }

    static func templatedHealth(score: HealthScoreResult, site: String) -> HealthNarrative {
        let trend: String
        if score.healthScore >= 70 { trend = "stable" }
        else if score.healthScore >= 40 { trend = "declining" }
        else { trend = "declining" }
        return HealthNarrative(
            headline: "Acoustic composite \(Int(score.healthScore.rounded())) at \(site)",
            narrative: "Unsupervised composite score \(String(format: "%.0f", score.healthScore))/100 (\(score.healthClass)). \(score.note)",
            trendDirection: trend,
            topDrivers: score.topDrivers.map { "\($0.feature) \(String(format: "%+.2f", $0.contribution))" },
            source: "template"
        )
    }

    static func alert(
        site: String,
        time: String,
        classLabel: String,
        pBlast: Double,
        alerted: Bool
    ) async -> AlertNarrative {
        let fallback = templatedAlert(site: site, time: time, pBlast: pBlast, alerted: alerted)
#if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return fallback }
        let session = LanguageModelSession()
        let prompt = """
        You are writing a short alert for a reef ranger. Use only these facts:
        site=\(site)
        time=\(time)
        modelClass=\(classLabel)
        blastProbability=\(String(format: "%.1f", pBlast * 100))%
        alerted=\(alerted)
        threshold=\(Int(PipelineConstants.blastThreshold * 100))%
        Do not invent extra sensors or locations. Severity must be high, medium, or low.
        If alerted is false, say it is not an alert.
        """
        do {
            let response = try await session.respond(to: prompt, generating: AlertSummarySchema.self)
            let content = response.content
            return AlertNarrative(
                headline: content.headline,
                severity: content.severity,
                explanation: content.explanation,
                recommendedAction: content.recommendedAction,
                source: "foundation_models"
            )
        } catch {
            return fallback
        }
#else
        return fallback
#endif
    }

    static func healthReport(score: HealthScoreResult, site: String) async -> HealthNarrative {
        let fallback = templatedHealth(score: score, site: site)
#if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return fallback }
        let session = LanguageModelSession()
        let drivers = score.topDrivers.map { "\($0.feature)=\(String(format: "%+.3f", $0.contribution))" }.joined(separator: ", ")
        let prompt = """
        Write a short reef acoustic-health note for a ranger. Use only these facts:
        site=\(site)
        compositeScore=\(String(format: "%.0f", score.healthScore))
        compositeClass=\(score.healthClass)
        ndsi=\(String(format: "%.2f", score.indices.ndsi))
        snapRatePerMin=\(String(format: "%.1f", score.indices.snapRatePerMin))
        lowFreqSPL_dB=\(String(format: "%.1f", score.indices.lowFreqSPL_dB))
        blastEventCountLastHour=\(score.blastEventCountLastHour)
        topDrivers=\(drivers)
        This is an unsupervised composite, not a trained healthy/degraded medical diagnosis.
        Trend must be improving, declining, or stable.
        """
        do {
            let response = try await session.respond(to: prompt, generating: HealthReportSchema.self)
            let content = response.content
            return HealthNarrative(
                headline: content.headline,
                narrative: content.narrative,
                trendDirection: content.trendDirection,
                topDrivers: content.topDrivers,
                source: "foundation_models"
            )
        } catch {
            return fallback
        }
#else
        return fallback
#endif
    }
}

#if canImport(FoundationModels)
@Generable
struct AlertSummarySchema {
    var headline: String
    var severity: String
    var explanation: String
    var recommendedAction: String
}

@Generable
struct HealthReportSchema {
    var headline: String
    var narrative: String
    var trendDirection: String
    var topDrivers: [String]
}
#endif
