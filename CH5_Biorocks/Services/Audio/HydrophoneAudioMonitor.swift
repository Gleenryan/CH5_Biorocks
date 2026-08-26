import AVFoundation
import Foundation

/// Plays incoming simulator PCM through the Mac speakers and keeps a replayable clip per hydrophone.
/// Each live hydrophone gets its own player node so the fleet mixes instead of only the first hydro playing.
nonisolated final class HydrophoneAudioMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "reefguard.audio.monitor")
    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var engineStarted = false
    private var players: [String: AVAudioPlayerNode] = [:]
    private var listenedID: String?
    private var mixAll = false
    private var clips: [String: [Float]] = [:]
    /// Main-thread gate so Mute / End simulator can silence queued buffers even if PCM is still in flight.
    private var playbackArmed = false

    /// Scenario mixes are quiet (RMS often ~0.02). Boost for monitor playback only.
    private let soloGain: Float = 10
    private let mixGain: Float = 4

    init() {
        format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: PipelineConstants.sampleRate,
            channels: 1,
            interleaved: false
        )!
    }

    /// Play every live hydrophone together as they stream in.
    func startMixingAll() {
        queue.sync {
            self.listenedID = nil
            self.mixAll = true
        }
        playbackArmed = true
        ensureEngine()
        engine.mainMixerNode.outputVolume = 1
    }

    func setListenedID(_ id: String?) {
        queue.async { [weak self] in
            guard let self else { return }
            let changed = self.listenedID != id || self.mixAll
            self.listenedID = id
            self.mixAll = false
            DispatchQueue.main.async {
                if id != nil {
                    self.armPlayback(flush: changed)
                } else {
                    self.silenceImmediately()
                }
            }
        }
    }

    /// Cut speaker output immediately. Call from the main actor so queued PCM cannot keep playing.
    func stopPlayback() {
        playbackArmed = false
        silenceImmediately()
        queue.async { [weak self] in
            self?.listenedID = nil
            self?.mixAll = false
        }
    }

    func ingest(hydrophoneID: String, samples: [Double]) {
        guard !samples.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.appendClip(id: hydrophoneID, samples: samples)
            let play = self.mixAll || self.listenedID == hydrophoneID
            guard play else { return }
            let samplesToPlay = samples
            let gain = self.mixAll ? self.mixGain : self.soloGain
            DispatchQueue.main.async {
                self.schedule(id: hydrophoneID, samples: samplesToPlay, gain: gain)
            }
        }
    }

    func replay(hydrophoneID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let clip = self.clips[hydrophoneID] ?? []
            self.listenedID = hydrophoneID
            self.mixAll = false
            DispatchQueue.main.async {
                self.armPlayback(flush: true)
                guard !clip.isEmpty else { return }
                self.schedule(id: hydrophoneID, samples: clip.map(Double.init), gain: self.soloGain)
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

    private func schedule(id: String, samples: [Double], gain: Float) {
        guard playbackArmed else { return }
        ensureEngine()
        let player = playerNode(for: id)
        guard let buffer = makeBuffer(samples, gain: gain) else { return }
        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer)
    }

    private func playerNode(for id: String) -> AVAudioPlayerNode {
        if let existing = players[id] {
            return existing
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        players[id] = player
        return player
    }

    private func armPlayback(flush: Bool) {
        playbackArmed = true
        ensureEngine()
        engine.mainMixerNode.outputVolume = 1
        if flush {
            flushPlayers(resume: true)
        }
    }

    private func silenceImmediately() {
        playbackArmed = false
        guard engineStarted else { return }
        engine.mainMixerNode.outputVolume = 0
        flushPlayers(resume: false)
    }

    private func flushPlayers(resume: Bool) {
        guard engineStarted else { return }
        for player in players.values {
            player.stop()
            player.reset()
            if resume {
                player.play()
            }
        }
    }

    private func makeBuffer(_ samples: [Double], gain: Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for index in samples.indices {
            let boosted = Float(samples[index]) * gain
            channel[index] = max(-1, min(1, boosted))
        }
        return buffer
    }

    private func ensureEngine() {
        guard !engineStarted else { return }
        engine.mainMixerNode.outputVolume = 1
        do {
            try engine.start()
            engineStarted = true
        } catch {
            engineStarted = false
        }
    }
}
