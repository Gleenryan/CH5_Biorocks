import Foundation

nonisolated struct AudioFeatureExtractor {
    private let nFFT = 512
    private let hop = 128
    private let nMels = 40
    private let nMFCC = 13
    private let filterbank: [[Double]]

    init(sampleRate: Double = PipelineConstants.sampleRate) {
        self.filterbank = Self.makeMelFilterbank(
            sampleRate: sampleRate,
            nFFT: 512,
            nMels: 40
        )
    }

    func extract(_ samples: [Double], sampleRate: Double = PipelineConstants.sampleRate) -> [Double] {
        var y = samples
        let n = Int((PipelineConstants.classifierWindowSeconds * sampleRate).rounded())
        if y.count < n {
            y += Array(repeating: 0.0, count: n - y.count)
        } else if y.count > n {
            var peak = 0
            var peakAbs = 0.0
            for (i, v) in y.enumerated() {
                if abs(v) > peakAbs {
                    peakAbs = abs(v)
                    peak = i
                }
            }
            let start = max(0, min(peak - n / 2, y.count - n))
            y = Array(y[start..<(start + n)])
        }

        let stft = DSP.stftMagnitudes(y, nFFT: nFFT, hop: hop)
        let freqs = stft.freqs
        let nBins = freqs.count
        var spec = Array(repeating: 1e-12, count: nBins)
        if !stft.mag.isEmpty {
            for k in 0..<nBins {
                var acc = 0.0
                for frame in stft.mag { acc += frame[k] }
                spec[k] = acc / Double(stft.mag.count) + 1e-12
            }
        }
        let specSum = spec.reduce(0, +)
        var centroid = 0.0
        for k in 0..<nBins { centroid += freqs[k] * spec[k] }
        centroid /= specSum

        var bandwidth = 0.0
        for k in 0..<nBins {
            let d = freqs[k] - centroid
            bandwidth += d * d * spec[k]
        }
        bandwidth = sqrt(bandwidth / specSum)

        var csum = Array(repeating: 0.0, count: nBins)
        csum[0] = spec[0]
        for k in 1..<nBins { csum[k] = csum[k - 1] + spec[k] }
        let target = 0.85 * csum[nBins - 1]
        var rollIdx = nBins - 1
        for k in 0..<nBins where csum[k] >= target {
            rollIdx = k
            break
        }
        let rolloff = freqs[rollIdx]
        let logMean = spec.map { log($0) }.reduce(0, +) / Double(spec.count)
        let flatness = exp(logMean) / (specSum / Double(spec.count))

        var zc = 0.0
        if y.count > 1 {
            for i in 1..<y.count {
                if (y[i] < 0) != (y[i - 1] < 0) { zc += 1 }
            }
            zc /= Double(y.count - 1)
        }
        let rms = sqrt(y.reduce(0.0) { $0 + $1 * $1 } / Double(y.count))
        let peak = (y.map { abs($0) }.max() ?? 0) + 1e-12
        let crest = peak / (rms + 1e-12)
        var low = 0.0
        var high = 0.0
        for k in 0..<nBins {
            if freqs[k] < 500 { low += spec[k] }
            if freqs[k] >= 2000 && freqs[k] <= 8000 { high += spec[k] }
        }
        low /= specSum
        high /= specSum

        let env = DSP.sosfilt(PipelineConstants.bandpassSOS, y).map { abs($0) }
        let smooth = DSP.movingAverage(env, window: max(1, Int(0.01 * sampleRate)))
        let half = 0.5 * (smooth.max() ?? 0)
        let above = smooth.filter { $0 >= half }.count
        let durMs = 1000.0 * Double(above) / sampleRate

        var mfccMeans = Array(repeating: 0.0, count: nMFCC)
        if !stft.mag.isEmpty {
            let nFrames = stft.mag.count
            for frame in stft.mag {
                var mel = Array(repeating: 0.0, count: nMels)
                for m in 0..<nMels {
                    var acc = 0.0
                    for k in 0..<nBins {
                        acc += filterbank[m][k] * frame[k]
                    }
                    mel[m] = log(max(acc, 1e-10))
                }
                for k in 0..<nMFCC {
                    var acc = 0.0
                    for m in 0..<nMels {
                        acc += cos(Double.pi * Double(k) * (Double(m) + 0.5) / Double(nMels)) * mel[m]
                    }
                    mfccMeans[k] += acc
                }
            }
            for k in 0..<nMFCC { mfccMeans[k] /= Double(nFrames) }
        }

        return [
            centroid, bandwidth, rolloff, flatness, zc, rms, crest, low, high, durMs
        ] + mfccMeans
    }

    private static func hzToMel(_ hz: Double) -> Double {
        2595.0 * log10(1.0 + hz / 700.0)
    }

    private static func melToHz(_ mel: Double) -> Double {
        700.0 * (pow(10.0, mel / 2595.0) - 1.0)
    }

    private static func makeMelFilterbank(sampleRate: Double, nFFT: Int, nMels: Int) -> [[Double]] {
        let nBins = nFFT / 2 + 1
        let maxHz = sampleRate / 2
        let mels = (0..<(nMels + 2)).map { i in
            let t = Double(i) / Double(nMels + 1)
            return hzToMel(0) + t * (hzToMel(maxHz) - hzToMel(0))
        }
        let hz = mels.map(melToHz)
        let bins = hz.map { Int(floor((Double(nFFT / 2 + 1) * $0 / maxHz))) }
        var fb = Array(repeating: Array(repeating: 0.0, count: nBins), count: nMels)
        for i in 0..<nMels {
            let left = bins[i]
            var cen = bins[i + 1]
            var right = bins[i + 2]
            if cen == left { cen += 1 }
            if right == cen { right += 1 }
            right = min(right, nBins - 1)
            cen = min(cen, nBins - 2)
            if cen > left {
                let span = cen - left
                for j in 0..<span {
                    fb[i][left + j] = Double(j) / Double(span)
                }
            }
            if right > cen {
                let span = right - cen
                for j in 0..<span {
                    fb[i][cen + j] = 1.0 - Double(j) / Double(span)
                }
            }
        }
        return fb
    }
}
