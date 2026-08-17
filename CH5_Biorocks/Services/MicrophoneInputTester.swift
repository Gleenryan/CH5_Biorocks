import AVFoundation
import AudioToolbox
import Combine
import CoreAudio

struct MicrophoneDevice: Identifiable, Hashable {
    let id: String
    let name: String

    /// Uses Core Audio device UIDs so the saved selection remains stable across launches.
    static func availableDevices() -> [MicrophoneDevice] {
        do {
            return try AudioHardwareSystem.shared.devices.compactMap { device in
                let inputStreams = try device.inputStreamConfiguration
                guard inputStreams.contains(where: { $0.mNumberChannels > 0 }) else {
                    return nil
                }

                return MicrophoneDevice(id: try device.uid, name: try device.name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            return []
        }
    }
}

enum MicrophoneInputStatus: Equatable {
    case idle
    case testing
    case receivingAudio
    case unavailable
    case permissionDenied
    case failed

    var isWorking: Bool {
        self == .receivingAudio
    }

    var message: String {
        switch self {
        case .idle:
            "Ready to test"
        case .testing:
            "Listening for audio…"
        case .receivingAudio:
            "Microphone is receiving audio"
        case .unavailable:
            "Selected microphone is unavailable"
        case .permissionDenied:
            "Microphone access is not allowed"
        case .failed:
            "Unable to receive audio"
        }
    }
}

/// Briefly opens the selected input and reports whether macOS delivers audio frames.
/// It doesn't save or record audio.
final class MicrophoneInputTester: ObservableObject {
    @Published private(set) var status: MicrophoneInputStatus = .idle
    @Published private(set) var isTesting = false

    private let engine = AVAudioEngine()
    private var hasReceivedAudio = false
    private var noAudioTimeout: DispatchWorkItem?

    func startTest(deviceID: String) {
        stopTest(resetStatus: false)

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            configureAndStart(deviceID: deviceID)

        case .notDetermined:
            status = .testing
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.configureAndStart(deviceID: deviceID) : self.updateStatus(.permissionDenied)
                }
            }

        case .denied, .restricted:
            updateStatus(.permissionDenied)

        @unknown default:
            updateStatus(.failed)
        }
    }

    func stopTest(resetStatus: Bool = true) {
        noAudioTimeout?.cancel()
        noAudioTimeout = nil
        isTesting = false
        hasReceivedAudio = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        if resetStatus {
            status = .idle
        }
    }

    private func configureAndStart(deviceID: String) {
        do {
            guard let device = try AudioHardwareSystem.shared.device(forUID: deviceID) else {
                updateStatus(.unavailable)
                return
            }

            let inputNode = engine.inputNode
            guard let audioUnit = inputNode.audioUnit else {
                updateStatus(.failed)
                return
            }

            var audioDeviceID = device.id
            let result = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &audioDeviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )

            guard result == noErr else {
                updateStatus(.failed)
                return
            }

            hasReceivedAudio = false
            isTesting = true
            status = .testing

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(
                onBus: 0,
                bufferSize: 1_024,
                format: inputNode.inputFormat(forBus: 0)
            ) { [weak self] _, _ in
                DispatchQueue.main.async {
                    guard let self, self.isTesting, !self.hasReceivedAudio else { return }
                    self.hasReceivedAudio = true
                    self.noAudioTimeout?.cancel()
                    self.status = .receivingAudio
                }
            }

            engine.prepare()
            try engine.start()
            scheduleNoAudioTimeout()
        } catch {
            updateStatus(.failed)
        }
    }

    private func scheduleNoAudioTimeout() {
        noAudioTimeout?.cancel()

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.isTesting, !self.hasReceivedAudio else { return }
            self.updateStatus(.failed)
        }

        noAudioTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
    }

    private func updateStatus(_ newStatus: MicrophoneInputStatus) {
        noAudioTimeout?.cancel()
        noAudioTimeout = nil
        isTesting = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        status = newStatus
    }
}
