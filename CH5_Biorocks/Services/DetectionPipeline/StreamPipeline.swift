import Foundation

nonisolated final class StreamPipeline: @unchecked Sendable {
    let hello: HydrophoneHello
    let startedAt: Date

    private let classifier: BlastClassifier
    private let extractor = AudioFeatureExtractor()
    private let gate = ImpulseGate()
    private var debouncer = EventDebouncer()
    private var buffer: [Double] = []
    private var processedThrough = 0
    private var lastGateOnset: TimeInterval = -1_000
    private var healthCursor = 0
    private var samplesReceived = 0
    private var model2Hits = 0
    private var model1Hits = 0
    private var promotions: [TimeInterval] = []
    private let sampleRate: Double
    private let hop: Int
    private let gateN: Int
    private let clfN: Int

    var onLog: (@Sendable (PipelineLogLine) -> Void)?
    var onStatus: (@Sendable (LiveHydrophoneStatus) -> Void)?
    var onPromote: (@Sendable (PromotedDetection) -> Void)?
    var onHealth: (@Sendable (HealthScoreResult) -> Void)?
    var onScorecard: (@Sendable (SimScorecard) -> Void)?

    init(hello: HydrophoneHello, classifier: BlastClassifier) {
        self.hello = hello
        self.classifier = classifier
        self.startedAt = Date()
        self.sampleRate = hello.sampleRate > 0 ? hello.sampleRate : PipelineConstants.sampleRate
        self.hop = Int(PipelineConstants.hopSeconds * sampleRate)
        self.gateN = Int(PipelineConstants.gateWindowSeconds * sampleRate)
        self.clfN = Int(PipelineConstants.classifierWindowSeconds * sampleRate)
    }

    private func liveStatus(connected: Bool, rms: Double, samples: Int, envelopeBins: [Double] = []) -> LiveHydrophoneStatus {
        LiveHydrophoneStatus(
            id: hello.hydrophoneId,
            name: hello.hydrophoneName,
            siteName: hello.siteName,
            scenarioName: hello.scenarioName,
            connected: connected,
            samplesReceived: samples,
            lastRMS: rms,
            connectedAt: startedAt,
            latitude: hello.latitude,
            longitude: hello.longitude,
            envelopeBins: envelopeBins
        )
    }

    func append(samples: [Double]) {
        buffer.append(contentsOf: samples)
        samplesReceived += samples.count
        let rms = sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Double(max(samples.count, 1)))
        onStatus?(liveStatus(connected: true, rms: rms, samples: samplesReceived, envelopeBins: peakBins(samples)))
        runGate()
        runHealthIfNeeded()
    }

    func finish() {
        scoreAgainstGroundTruth()
        onStatus?(liveStatus(connected: false, rms: 0, samples: samplesReceived))
    }

    private func peakBins(_ samples: [Double], count: Int = 8) -> [Double] {
        guard !samples.isEmpty else { return Array(repeating: 0, count: count) }
        let step = max(1, samples.count / count)
        return (0..<count).map { index in
            let start = index * step
            let end = min(samples.count, start + step)
            var peak = 0.0
            for sample in samples[start..<end] {
                peak = max(peak, abs(sample))
            }
            return peak
        }
    }

    private func runGate() {
        while processedThrough + gateN <= buffer.count {
            let start = processedThrough
            let window = Array(buffer[start..<(start + gateN)])
            let windowStart = Double(start) / sampleRate
            if let candidate = gate.evaluate(samples: window, sampleRate: sampleRate, windowStart: windowStart) {
                if candidate.onsetTime - lastGateOnset >= PipelineConstants.refractorySeconds {
                    lastGateOnset = candidate.onsetTime
                    model1Hits += 1
                    onLog?(
                        PipelineLogLine(
                            hydrophoneName: hello.hydrophoneName,
                            stage: "Model 1",
                            detail: String(
                                format: "impulse @ %.2fs  energyRatio=%.2f  band=%.1f dB",
                                candidate.onsetTime,
                                candidate.energyRatio,
                                candidate.bandEnergyDb
                            )
                        )
                    )
                    classify(candidate: candidate)
                }
            }
            processedThrough += hop
        }
        let keep = max(clfN * 2, gateN * 2)
        if buffer.count > keep + processedThrough {
            let drop = processedThrough - gateN
            if drop > 0 {
                buffer.removeFirst(drop)
                processedThrough -= drop
                healthCursor = max(0, healthCursor - drop)
            }
        }
    }

    private func classify(candidate: ImpulseCandidate) {
        let center = Int(candidate.onsetTime * sampleRate)
        let start = max(0, min(center - clfN / 2, buffer.count - min(clfN, buffer.count)))
        let end = min(buffer.count, start + clfN)
        let clip = Array(buffer[start..<end])
        let features = extractor.extract(clip, sampleRate: sampleRate)
        do {
            let result = try classifier.predict(features: features)
            let decision = debouncer.consider(time: candidate.onsetTime, pBlast: result.pBlast)
            if result.pBlast >= PipelineConstants.blastThreshold {
                model2Hits += 1
            }
            onLog?(
                PipelineLogLine(
                    hydrophoneName: hello.hydrophoneName,
                    stage: "Model 2",
                    detail: String(
                        format: "%@  P(blast)=%.3f  debounce %d/%d %@",
                        result.topClass,
                        result.pBlast,
                        decision.votes,
                        decision.windowCount,
                        decision.promote ? "PROMOTE" : "hold"
                    )
                )
            )
            if decision.promote {
                if promotions.count >= PipelineConstants.maxPromotionsPerSession {
                    onLog?(
                        PipelineLogLine(
                            hydrophoneName: hello.hydrophoneName,
                            stage: "Alert",
                            detail: "Skipped promote — session already at \(PipelineConstants.maxPromotionsPerSession) blast alert(s)"
                        )
                    )
                    return
                }
                promotions.append(candidate.onsetTime)
                Task {
                    let timeText = ISO8601DateFormatter().string(from: Date().addingTimeInterval(candidate.onsetTime - elapsed()))
                    let narrative = await FoundationModelNarrator.alert(
                        site: hello.siteName,
                        time: timeText,
                        classLabel: result.topClass,
                        pBlast: result.pBlast,
                        alerted: true
                    )
                    let detection = PromotedDetection(
                        hydrophoneId: hello.hydrophoneId,
                        hydrophoneName: hello.hydrophoneName,
                        siteName: hello.siteName,
                        source: hello.source,
                        scenarioId: hello.scenarioId,
                        onsetTime: startedAt.addingTimeInterval(candidate.onsetTime),
                        streamTime: candidate.onsetTime,
                        pBlast: result.pBlast,
                        topClass: result.topClass,
                        topConfidence: result.topConfidence,
                        probabilities: result.classProbabilities,
                        energyRatio: candidate.energyRatio,
                        bandEnergyDb: candidate.bandEnergyDb,
                        narrative: narrative
                    )
                    self.onPromote?(detection)
                    self.onLog?(
                        PipelineLogLine(
                            hydrophoneName: self.hello.hydrophoneName,
                            stage: "Alert",
                            detail: "\(narrative.headline) [\(narrative.source)]"
                        )
                    )
                }
            }
        } catch {
            onLog?(
                PipelineLogLine(
                    hydrophoneName: hello.hydrophoneName,
                    stage: "Model 2",
                    detail: "classifier error: \(error.localizedDescription)"
                )
            )
        }
    }

    private func runHealthIfNeeded() {
        let period = Int(PipelineConstants.healthPeriodSeconds * sampleRate)
        let available = min(buffer.count, Int(hello.durationSeconds * sampleRate) + Int(sampleRate))
        // Score at 8s into the stream and at the end-ish so short scenarios still get a snapshot.
        let firstAt = min(period, Int(8 * sampleRate))
        if healthCursor == 0 && buffer.count >= firstAt {
            emitHealth(from: 0, count: firstAt)
            healthCursor = firstAt
        }
        if buffer.count - healthCursor >= period {
            emitHealth(from: buffer.count - period, count: period)
            healthCursor = buffer.count
        }
        _ = available
    }

    private func emitHealth(from start: Int, count: Int) {
        let slice = Array(buffer[start..<min(buffer.count, start + count)])
        guard slice.count > Int(sampleRate / 4) else { return }
        let indices = HealthScorer.indices(from: slice, sampleRate: sampleRate)
        let score = HealthScorer.score(indices, blastEventCountLastHour: promotions.count)
        onHealth?(score)
        Task {
            let narrative = await FoundationModelNarrator.healthReport(score: score, site: hello.siteName)
            self.onLog?(
                PipelineLogLine(
                    hydrophoneName: self.hello.hydrophoneName,
                    stage: "Health",
                    detail: "\(narrative.headline) [\(narrative.source)]"
                )
            )
        }
        onLog?(
            PipelineLogLine(
                hydrophoneName: hello.hydrophoneName,
                stage: "Health",
                detail: String(
                    format: "composite %.0f (%@)  NDSI %.2f  snaps/min %.0f",
                    score.healthScore,
                    score.healthClass,
                    score.indices.ndsi,
                    score.indices.snapRatePerMin
                )
            )
        )
    }

    private func scoreAgainstGroundTruth() {
        let expected = hello.events.filter(\.expectedAlert)
        var matched = Set<String>()
        var tp = 0
        var fp = 0
        for onset in promotions {
            var best: GroundTruthWire?
            var bestDt = PipelineConstants.matchWindowSeconds + 1
            for gt in expected where !matched.contains(gt.id) {
                let dt = abs(onset - gt.tOnsetSeconds)
                if dt <= PipelineConstants.matchWindowSeconds && dt < bestDt {
                    bestDt = dt
                    best = gt
                }
            }
            if let best {
                tp += 1
                matched.insert(best.id)
            } else {
                fp += 1
            }
        }
        let fn = expected.count - matched.count
        let model1Misses = expected.filter { gt in
            !promotions.contains { abs($0 - gt.tOnsetSeconds) <= 4 }
            && model1Hits == 0
        }.count
        onScorecard?(
            SimScorecard(
                scenarioId: hello.scenarioId,
                tp: tp,
                fp: fp,
                fn: fn,
                model1Misses: model1Misses,
                debounceDrops: max(0, model2Hits - promotions.count)
            )
        )
    }

    private func elapsed() -> TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
}
