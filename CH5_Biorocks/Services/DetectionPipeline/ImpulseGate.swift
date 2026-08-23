import Foundation

nonisolated struct ImpulseCandidate: Sendable {
    var onsetTime: TimeInterval
    var energyRatio: Double
    var bandEnergyDb: Double
    var durationEstimateMs: Double
}

nonisolated struct ImpulseGate {
    var nSigma: Double = PipelineConstants.nSigma
    var refractorySeconds: Double = PipelineConstants.refractorySeconds

    func evaluate(samples: [Double], sampleRate: Double, windowStart: TimeInterval) -> ImpulseCandidate? {
        guard samples.count >= Int(sampleRate / 10) else { return nil }
        let filt = DSP.sosfilt(PipelineConstants.bandpassSOS, samples)
        var env = filt.map { abs($0) }
        let win = max(1, Int(0.020 * sampleRate))
        env = DSP.movingAverage(env, window: win)
        let med = DSP.median(env)
        let sd = DSP.std(env)
        let thresh = med + nSigma * sd
        let minGap = Int(refractorySeconds * sampleRate)
        var last = -minGap
        var onsets: [Int] = []
        var i = 0
        while i < env.count {
            if env[i] > thresh && (i - last) >= minGap {
                onsets.append(i)
                last = i
                i += minGap
            } else {
                i += 1
            }
        }
        guard let first = onsets.first else { return nil }

        let bandPow = filt.reduce(0.0) { $0 + $1 * $1 } / Double(filt.count) + 1e-12
        let fullPow = samples.reduce(0.0) { $0 + $1 * $1 } / Double(samples.count) + 1e-12
        var longest = 0
        var run = 0
        for v in env {
            if v > thresh {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        return ImpulseCandidate(
            onsetTime: windowStart + Double(first) / sampleRate,
            energyRatio: bandPow / fullPow,
            bandEnergyDb: 10 * log10(bandPow),
            durationEstimateMs: 1000.0 * Double(longest) / sampleRate
        )
    }
}
