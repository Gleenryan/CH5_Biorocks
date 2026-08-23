import AVFoundation
import Foundation

/// Plays incoming simulator PCM through the Mac speakers and keeps a replayable clip per hydrophone.
nonisolated final class HydrophoneAudioMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "reefguard.audio.monitor")
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var engineStarted = false
    private var listenedID: String?
    private var clips: [String: [Float]] = [:]

    /// Scenario mixes are quiet (RMS often ~0.02). Boost for monitor playback only.
    private let monitorGain: Float = 10

    init() {
        format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: PipelineConstants.sampleRate,
            channels: 1,
            interleaved: false
        )!
    }

    func setListenedID(_ id: String?) {
        queue.async { [weak self] in
            guard let self else { return }
            self.listenedID = id
            if id != nil {
                DispatchQueue.main.async {
                    self.ensureEngine()
                }
            }
        }
    }

    func ingest(hydrophoneID: String, samples: [Double]) {
        guard !samples.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.appendClip(id: hydrophoneID, samples: samples)
            guard self.listenedID == hydrophoneID else { return }
            DispatchQueue.main.async {
                self.schedule(samples)
            }
        }
    }

    func replay(hydrophoneID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let clip = self.clips[hydrophoneID] ?? []
            DispatchQueue.main.async {
                self.ensureEngine()
                self.player.stop()
                self.player.play()
                guard !clip.isEmpty else { return }
                self.schedule(clip.map(Double.init))
            }
        }
    }

    func hasClip(hydrophoneID: String) -> Bool {
        queue.sync { !(clips[hydrophoneID] ?? []).isEmpty }
    }

    private func appendClip(id: String, samples: [Double]) {
        var clip = clips[id] ?? []
        clip.reserveCapacity(clip.count + samples.count)
        clip.append(contentsOf: samples.map { Float($0) })
        let maxSamples = Int(PipelineConstants.sampleRate * 45)
        if clip.count > maxSamples {
            clip.removeFirst(clip.count - maxSamples)
        }
        clips[id] = clip
    }

    private func schedule(_ samples: [Double]) {
        ensureEngine()
        guard let buffer = makeBuffer(samples) else { return }
        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer)
    }

    private func makeBuffer(_ samples: [Double]) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for index in samples.indices {
            let boosted = Float(samples[index]) * monitorGain
            channel[index] = max(-1, min(1, boosted))
        }
        return buffer
    }

    private func ensureEngine() {
        guard !engineStarted else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        do {
            try engine.start()
            player.play()
            engineStarted = true
        } catch {
            engineStarted = false
        }
    }
}
