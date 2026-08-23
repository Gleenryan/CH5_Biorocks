import CoreML
import Foundation

nonisolated struct SoundClassifierResult: Sendable {
    var topClass: String
    var topConfidence: Double
    var pBlast: Double
    var classProbabilities: [String: Double]
}

nonisolated final class BlastClassifier: @unchecked Sendable {
    private let model: MLModel

    init() throws {
        guard let url = Bundle.main.url(forResource: "BlastEventClassifier", withExtension: "mlpackage")
                ?? Bundle.main.url(forResource: "BlastEventClassifier", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "BlastEventClassifier", withExtension: "mlmodel") else {
            throw NSError(
                domain: "ReefGuard",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "BlastEventClassifier is missing from the app bundle."]
            )
        }
        model = try MLModel(contentsOf: url)
    }

    func predict(features: [Double]) throws -> SoundClassifierResult {
        let array = try MLMultiArray(shape: [23], dataType: .double)
        for (i, value) in features.enumerated() where i < 23 {
            array[i] = NSNumber(value: value)
        }
        let out = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "features": MLFeatureValue(multiArray: array)
        ]))
        let label = out.featureValue(for: "classLabel")?.stringValue ?? "?"
        let probs = out.featureValue(for: "classProbability")?.dictionaryValue as? [AnyHashable: NSNumber] ?? [:]
        var mapped: [String: Double] = [:]
        for (key, value) in probs {
            mapped["\(key)"] = value.doubleValue
        }
        let pBlast = mapped["blast"] ?? 0
        return SoundClassifierResult(
            topClass: label,
            topConfidence: mapped[label] ?? pBlast,
            pBlast: pBlast,
            classProbabilities: mapped
        )
    }
}
