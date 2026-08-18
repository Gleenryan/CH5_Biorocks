import Foundation

nonisolated struct ComplexValue {
    var re: Double
    var im: Double

    static let zero = ComplexValue(re: 0, im: 0)

    static func + (lhs: ComplexValue, rhs: ComplexValue) -> ComplexValue {
        ComplexValue(re: lhs.re + rhs.re, im: lhs.im + rhs.im)
    }

    static func - (lhs: ComplexValue, rhs: ComplexValue) -> ComplexValue {
        ComplexValue(re: lhs.re - rhs.re, im: lhs.im - rhs.im)
    }

    static func * (lhs: ComplexValue, rhs: ComplexValue) -> ComplexValue {
        ComplexValue(
            re: lhs.re * rhs.re - lhs.im * rhs.im,
            im: lhs.re * rhs.im + lhs.im * rhs.re
        )
    }

    var magnitude: Double { hypot(re, im) }
}

nonisolated enum DSP {
    static func sosfilt(_ sections: [[Double]], _ x: [Double]) -> [Double] {
        var y = x
        for section in sections {
            let b0 = section[0], b1 = section[1], b2 = section[2]
            let a1 = section[4], a2 = section[5]
            var z1 = 0.0, z2 = 0.0
            for i in 0..<y.count {
                let xi = y[i]
                let yi = b0 * xi + z1
                z1 = b1 * xi - a1 * yi + z2
                z2 = b2 * xi - a2 * yi
                y[i] = yi
            }
        }
        return y
    }

    static func movingAverage(_ x: [Double], window: Int) -> [Double] {
        if window <= 1 { return x }
        var out = Array(repeating: 0.0, count: x.count)
        var acc = 0.0
        for i in 0..<x.count {
            acc += x[i]
            if i >= window { acc -= x[i - window] }
            let denom = Double(min(i + 1, window))
            out[i] = acc / denom
        }
        return out
    }

    static func hannPeriodic(count: Int) -> [Double] {
        (0..<count).map { 0.5 * (1 - cos(2 * Double.pi * Double($0) / Double(count))) }
    }

    static func fft(_ realInput: [Double]) -> [ComplexValue] {
        let n = realInput.count
        precondition(n > 0 && n.nonzeroBitCount == 1, "FFT size must be a power of two")
        var a = realInput.map { ComplexValue(re: $0, im: 0) }
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j ^= bit
            if i < j { a.swapAt(i, j) }
        }
        var len = 2
        while len <= n {
            let angle = -2.0 * Double.pi / Double(len)
            let wlen = ComplexValue(re: cos(angle), im: sin(angle))
            var i = 0
            while i < n {
                var w = ComplexValue(re: 1, im: 0)
                for k in 0..<(len / 2) {
                    let u = a[i + k]
                    let v = a[i + k + len / 2] * w
                    a[i + k] = u + v
                    a[i + k + len / 2] = u - v
                    w = w * wlen
                }
                i += len
            }
            len <<= 1
        }
        return a
    }

    static func stftMagnitudes(
        _ y: [Double],
        nFFT: Int = 512,
        hop: Int = 128
    ) -> (freqs: [Double], mag: [[Double]]) {
        let window = hannPeriodic(count: nFFT)
        let windowSum = window.reduce(0, +)
        let nFrames = max(0, (y.count - nFFT) / hop + 1)
        var mag = Array(repeating: Array(repeating: 0.0, count: nFFT / 2 + 1), count: nFrames)
        if nFrames == 0 { return (freqs: [], mag: mag) }
        for frame in 0..<nFrames {
            let start = frame * hop
            var buf = Array(repeating: 0.0, count: nFFT)
            for i in 0..<nFFT {
                buf[i] = y[start + i] * window[i]
            }
            let spec = fft(buf)
            for k in 0...(nFFT / 2) {
                mag[frame][k] = spec[k].magnitude / windowSum
            }
        }
        let freqs = (0...(nFFT / 2)).map { Double($0) * PipelineConstants.sampleRate / Double(nFFT) }
        return (freqs, mag)
    }

    static func mean(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        return x.reduce(0, +) / Double(x.count)
    }

    static func median(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        let s = x.sorted()
        let m = s.count / 2
        if s.count % 2 == 0 {
            return (s[m - 1] + s[m]) / 2
        }
        return s[m]
    }

    static func std(_ x: [Double]) -> Double {
        guard x.count > 1 else { return 0 }
        let m = mean(x)
        let v = x.reduce(0.0) { $0 + ($1 - m) * ($1 - m) } / Double(x.count)
        return sqrt(v)
    }
}
