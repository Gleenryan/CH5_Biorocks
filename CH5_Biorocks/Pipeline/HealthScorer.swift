import Foundation

nonisolated struct HealthIndices: Sendable {
    var aci: Double
    var adi: Double
    var aei: Double
    var ndsi: Double
    var lowFreqSPL_dB: Double
    var snapRatePerMin: Double
    var biophonyRatio: Double
    var anthrophonyRatio: Double
}

nonisolated struct FeatureContribution: Sendable, Identifiable {
    var feature: String
    var contribution: Double
    var id: String { feature }
}

nonisolated struct HealthScoreResult: Sendable {
    var indices: HealthIndices
    var healthScore: Double
    var healthClass: String
    var topDrivers: [FeatureContribution]
    var blastEventCountLastHour: Int
    var note: String
}

nonisolated enum HealthScorer {
    static let weights: [String: Double] = [
        "ndsi": 0.20,
        "adi": 0.10,
        "aei": 0.10,
        "snapRatePerMin": 0.15,
        "biophonyRatio": 0.20,
        "anthrophonyRatio": -0.15,
        "blastEventCount": -0.10
    ]

    static func indices(from samples: [Double], sampleRate: Double = PipelineConstants.sampleRate) -> HealthIndices {
        let stft = DSP.stftMagnitudes(samples, nFFT: 512, hop: 256)
        let freqs = stft.freqs
        let frames = stft.mag
        let nBins = freqs.count
        var aci = 0.0
        if frames.count > 1 {
            for k in 0..<nBins {
                for t in 1..<frames.count {
                    aci += abs(frames[t][k] - frames[t - 1][k])
                }
            }
            aci /= Double(nBins * max(frames.count - 1, 1))
        }

        let edges = logspace(50, min(8000, sampleRate / 2 - 1), count: 11)
        var bandE = Array(repeating: 1e-12, count: 10)
        for t in frames {
            for b in 0..<10 {
                let a = edges[b], c = edges[b + 1]
                for k in 0..<nBins where freqs[k] >= a && freqs[k] < c {
                    bandE[b] += t[k]
                }
            }
        }
        let bandSum = bandE.reduce(0, +)
        let p = bandE.map { $0 / bandSum }
        let adi = -zip(p, p).map { $0 * log($1) }.reduce(0, +) / log(Double(p.count))
        let aei = 1.0 - gini(bandE)

        var aPow = 1e-12, bPow = 1e-12, total = 1e-12
        for t in frames {
            for k in 0..<nBins {
                total += t[k]
                if freqs[k] >= 100 && freqs[k] < 1500 { aPow += t[k] }
                if freqs[k] >= 2000 && freqs[k] <= 8000 { bPow += t[k] }
            }
        }
        let ndsi = (bPow - aPow) / (bPow + aPow + 1e-12)
        let lf = DSP.sosfilt(PipelineConstants.lowpass2kSOS, samples)
        let lfSpl = 10 * log10(lf.reduce(0.0) { $0 + $1 * $1 } / Double(max(lf.count, 1)) + 1e-12)

        var hf = DSP.sosfilt(PipelineConstants.highpass2to8kSOS, samples).map { abs($0) }
        hf = DSP.movingAverage(hf, window: max(1, Int(0.005 * sampleRate)))
        let med = DSP.median(hf)
        let sd = DSP.std(hf)
        let thr = med + 6 * sd
        let minGap = Int(0.01 * sampleRate)
        var nSnaps = 0
        var last = -minGap
        var prev = false
        for i in 0..<hf.count {
            let now = hf[i] > thr
            if now && !prev && (i - last) >= minGap {
                nSnaps += 1
                last = i
            }
            prev = now
        }
        let dur = Double(samples.count) / sampleRate
        return HealthIndices(
            aci: aci,
            adi: adi,
            aei: aei,
            ndsi: ndsi,
            lowFreqSPL_dB: lfSpl,
            snapRatePerMin: Double(nSnaps) / max(dur, 1e-6) * 60,
            biophonyRatio: bPow / total,
            anthrophonyRatio: aPow / total
        )
    }

    static func score(_ indices: HealthIndices, blastEventCountLastHour: Int) -> HealthScoreResult {
        let ndsiN = (indices.ndsi + 1) / 2
        let snapN = min(indices.snapRatePerMin / 600.0, 1)
        let blastN = min(Double(blastEventCountLastHour) / 10.0, 1)
        let contrib: [(String, Double)] = [
            ("ndsi", weights["ndsi"]! * ndsiN),
            ("adi", weights["adi"]! * indices.adi),
            ("aei", weights["aei"]! * indices.aei),
            ("snapRatePerMin", weights["snapRatePerMin"]! * snapN),
            ("biophonyRatio", weights["biophonyRatio"]! * indices.biophonyRatio),
            ("anthrophonyRatio", weights["anthrophonyRatio"]! * indices.anthrophonyRatio),
            ("blastEventCount", weights["blastEventCount"]! * blastN)
        ]
        let raw = contrib.reduce(0.0) { partial, item in
            partial + item.1
        }
        let score = min(max(50 + 80 * raw, 0), 100)
        let klass: String
        if score >= 70 { klass = "healthy" }
        else if score >= 40 { klass = "moderate" }
        else { klass = "degraded" }
        let top = contrib.sorted { abs($0.1) > abs($1.1) }.prefix(3).map {
            FeatureContribution(feature: $0.0, contribution: $0.1)
        }
        return HealthScoreResult(
            indices: indices,
            healthScore: score,
            healthClass: klass,
            topDrivers: Array(top),
            blastEventCountLastHour: blastEventCountLastHour,
            note: "Hand-weighted unsupervised composite — not a trained classifier."
        )
    }

    private static func logspace(_ a: Double, _ b: Double, count: Int) -> [Double] {
        guard count > 1 else { return [a] }
        let la = log10(a), lb = log10(b)
        return (0..<count).map { i in
            pow(10.0, la + (lb - la) * Double(i) / Double(count - 1))
        }
    }

    private static func gini(_ x: [Double]) -> Double {
        let vals = x.map { abs($0) }.sorted()
        let n = vals.count
        let sum = vals.reduce(0, +)
        guard n > 0, sum > 0 else { return 0 }
        var acc = 0.0
        for (i, v) in vals.enumerated() {
            acc += Double(i + 1) * v
        }
        return 2.0 * acc / (Double(n) * sum) - Double(n + 1) / Double(n)
    }
}
