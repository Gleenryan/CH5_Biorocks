import Combine
import Foundation

@MainActor
final class HydrophoneHub: ObservableObject {
    @Published private(set) var running = false
    private var started = false

    private let server = HydrophoneIngressServer()
    private let audioMonitor: HydrophoneAudioMonitor
    private let engine: PipelineEngine
    private var store: DetectionStore?

    init() {
        let monitor = HydrophoneAudioMonitor()
        audioMonitor = monitor
        engine = PipelineEngine(audioMonitor: monitor)
    }

    func attach(store: DetectionStore) {
        self.store = store
        engine.storeHandler = { [weak self] action in
            Task { @MainActor in
                self?.apply(action)
            }
        }
    }

    func toggleListen(hydrophoneID: String) {
        store?.toggleListen(id: hydrophoneID)
        audioMonitor.setListenedID(store?.listeningHydrophoneID)
    }

    func replay(hydrophoneID: String) {
        store?.listeningHydrophoneID = hydrophoneID
        audioMonitor.setListenedID(hydrophoneID)
        audioMonitor.replay(hydrophoneID: hydrophoneID)
    }

    func start() {
        guard !started else { return }
        started = true
        engine.prepareClassifier()
        apply(engine.bootstrapStatus())

        server.onReady = { [weak self] in
            Task { @MainActor in
                self?.running = true
                self?.store?.serverReady = true
                self?.store?.serverError = nil
            }
        }
        server.onError = { [weak self] message in
            Task { @MainActor in
                self?.store?.serverReady = false
                self?.store?.serverError = message
            }
        }
        server.onHello = { [weak engine] sessionID, hello in
            engine?.begin(sessionID: sessionID, hello: hello)
        }
        server.onPCM = { [weak engine] sessionID, samples in
            engine?.append(sessionID: sessionID, samples: samples)
        }
        server.onClose = { [weak engine] sessionID in
            engine?.finish(sessionID: sessionID)
        }
        server.start()
        store?.appendLog(
            PipelineLogLine(
                hydrophoneName: "Hub",
                stage: "Server",
                detail: "Listening on 127.0.0.1:\(PipelineConstants.listenPort) for Python hydrophones"
            )
        )
    }

    private func apply(_ action: PipelineUIAction) {
        switch action {
        case .classifier(let ready, let error):
            store?.classifierReady = ready
            store?.classifierError = error
        case .log(let line):
            store?.appendLog(line)
        case .status(let status):
            store?.upsertHydrophone(status)
            if status.connected, store?.listeningHydrophoneID == nil {
                store?.listeningHydrophoneID = status.id
                audioMonitor.setListenedID(status.id)
            }
        case .disconnected(let id):
            store?.markDisconnected(id: id)
            if store?.listeningHydrophoneID == id {
                store?.listeningHydrophoneID = nil
                audioMonitor.setListenedID(nil)
            }
        case .detection(let detection):
            store?.persist(detection)
        case .health(let score, let site, let hydrophone, let narrative):
            store?.persist(health: score, siteName: site, hydrophoneName: hydrophone, narrative: narrative)
        case .scorecard(let card):
            store?.lastScorecard = card
        }
    }
}

nonisolated enum PipelineUIAction: Sendable {
    case classifier(ready: Bool, error: String?)
    case log(PipelineLogLine)
    case status(LiveHydrophoneStatus)
    case disconnected(String)
    case detection(PromotedDetection)
    case health(HealthScoreResult, String, String, HealthNarrative)
    case scorecard(SimScorecard)
}

nonisolated final class PipelineEngine: @unchecked Sendable {
    var storeHandler: (@Sendable (PipelineUIAction) -> Void)?

    private let queue = DispatchQueue(label: "reefguard.pipeline", qos: .userInitiated)
    private let audioMonitor: HydrophoneAudioMonitor?
    private var classifier: BlastClassifier?
    private var classifierError: String?
    private var pipelines: [UUID: StreamPipeline] = [:]
    private var hydrophoneIDs: [UUID: String] = [:]

    init(audioMonitor: HydrophoneAudioMonitor? = nil) {
        self.audioMonitor = audioMonitor
    }

    func prepareClassifier() {
        queue.sync {
            do {
                classifier = try BlastClassifier()
                classifierError = nil
            } catch {
                classifier = nil
                classifierError = error.localizedDescription
            }
        }
    }

    func bootstrapStatus() -> PipelineUIAction {
        queue.sync {
            .classifier(ready: classifier != nil, error: classifierError)
        }
    }

    func begin(sessionID: UUID, hello: HydrophoneHello) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let classifier = self.classifier else {
                self.emit(.log(PipelineLogLine(
                    hydrophoneName: hello.hydrophoneName,
                    stage: "Error",
                    detail: self.classifierError ?? "Core ML model not loaded"
                )))
                return
            }

            let pipeline = StreamPipeline(hello: hello, classifier: classifier)
            pipeline.onLog = { [weak self] line in self?.emit(.log(line)) }
            pipeline.onStatus = { [weak self] status in self?.emit(.status(status)) }
            pipeline.onPromote = { [weak self] detection in self?.emit(.detection(detection)) }
            pipeline.onHealth = { [weak self] score in
                Task {
                    let narrative = await FoundationModelNarrator.healthReport(score: score, site: hello.siteName)
                    self?.emit(.health(score, hello.siteName, hello.hydrophoneName, narrative))
                }
            }
            pipeline.onScorecard = { [weak self] card in self?.emit(.scorecard(card)) }
            self.pipelines[sessionID] = pipeline
            self.hydrophoneIDs[sessionID] = hello.hydrophoneId
            self.audioMonitor?.setListenedID(hello.hydrophoneId)
            self.emit(.log(PipelineLogLine(
                hydrophoneName: hello.hydrophoneName,
                stage: "Connect",
                detail: "\(hello.scenarioName) → \(hello.siteName)"
            )))
            self.emit(.status(LiveHydrophoneStatus(
                id: hello.hydrophoneId,
                name: hello.hydrophoneName,
                siteName: hello.siteName,
                scenarioName: hello.scenarioName,
                connected: true,
                samplesReceived: 0,
                lastRMS: 0,
                connectedAt: Date(),
                latitude: hello.latitude,
                longitude: hello.longitude
            )))
        }
    }

    func append(sessionID: UUID, samples: [Double]) {
        queue.async { [weak self] in
            guard let self else { return }
            self.pipelines[sessionID]?.append(samples: samples)
            if let hydrophoneID = self.hydrophoneIDs[sessionID] {
                self.audioMonitor?.ingest(hydrophoneID: hydrophoneID, samples: samples)
            }
        }
    }

    func finish(sessionID: UUID) {
        queue.async { [weak self] in
            guard let self else { return }
            let hydroID = self.hydrophoneIDs[sessionID]
            self.pipelines[sessionID]?.finish()
            self.pipelines.removeValue(forKey: sessionID)
            self.hydrophoneIDs.removeValue(forKey: sessionID)
            if let hydroID {
                self.emit(.disconnected(hydroID))
            }
        }
    }

    private func emit(_ action: PipelineUIAction) {
        storeHandler?(action)
    }
}
