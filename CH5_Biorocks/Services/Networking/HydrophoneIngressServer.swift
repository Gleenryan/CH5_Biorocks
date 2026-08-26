import Foundation
import Network

nonisolated final class HydrophoneIngressServer: @unchecked Sendable {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "reefguard.hydrophone.ingress")
    private var sessions: [UUID: ConnectionSession] = [:]

    var onHello: (@Sendable (UUID, HydrophoneHello) -> Void)?
    var onPCM: (@Sendable (UUID, [Double]) -> Void)?
    var onClose: (@Sendable (UUID) -> Void)?
    var onReady: (@Sendable () -> Void)?
    var onError: (@Sendable (String) -> Void)?

    func start(port: UInt16 = PipelineConstants.listenPort) {
        do {
            let params = NWParameters.tcp
            params.acceptLocalOnly = true
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            onError?(error.localizedDescription)
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onReady?()
            case .failed(let error):
                self?.onError?(error.localizedDescription)
            default:
                break
            }
        }
        listener?.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        dropAllSessions()
    }

    func dropAllSessions() {
        queue.async { [weak self] in
            guard let self else { return }
            let current = Array(self.sessions.values)
            for session in current {
                session.forceClose()
            }
        }
    }

    private func accept(_ connection: NWConnection) {
        let sessionID = UUID()
        let session = ConnectionSession(
            id: sessionID,
            connection: connection,
            onHello: { [weak self] hello in self?.onHello?(sessionID, hello) },
            onPCM: { [weak self] samples in self?.onPCM?(sessionID, samples) },
            onClose: { [weak self] in
                self?.sessions.removeValue(forKey: sessionID)
                self?.onClose?(sessionID)
            }
        )
        connection.stateUpdateHandler = { state in
            switch state {
            case .failed, .cancelled:
                session.fail()
            default:
                break
            }
        }
        connection.start(queue: queue)
        session.receive()
        sessions[sessionID] = session
    }
}

nonisolated private final class ConnectionSession: @unchecked Sendable {
    let id: UUID
    let connection: NWConnection
    let onHello: (HydrophoneHello) -> Void
    let onPCM: ([Double]) -> Void
    let onClose: () -> Void

    private var buffer = Data()
    private var handshakeDone = false
    private var closed = false

    init(
        id: UUID,
        connection: NWConnection,
        onHello: @escaping (HydrophoneHello) -> Void,
        onPCM: @escaping ([Double]) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.id = id
        self.connection = connection
        self.onHello = onHello
        self.onPCM = onPCM
        self.onClose = onClose
    }

    func fail() {
        guard !closed else { return }
        closed = true
        onClose()
    }

    func forceClose() {
        connection.cancel()
        fail()
    }

    func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, !self.closed else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.consume()
            }
            if isComplete || error != nil {
                self.fail()
                return
            }
            self.receive()
        }
    }

    private func consume() {
        if !handshakeDone {
            guard let newline = buffer.firstIndex(of: 0x0A) else { return }
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            if newline + 1 <= buffer.endIndex {
                buffer.removeSubrange(buffer.startIndex...newline)
            }
            do {
                let hello = try HydrophoneHello.decode(line)
                handshakeDone = true
                onHello(hello)
                let ack = #"{"type":"ack","ok":true,"protocol":"\#(PipelineConstants.protocolName)"}"# + "\n"
                connection.send(content: Data(ack.utf8), completion: .contentProcessed { _ in })
            } catch {
                let message = error.localizedDescription.replacingOccurrences(of: "\"", with: "'")
                let ack = "{\"type\":\"ack\",\"ok\":false,\"error\":\"\(message)\"}\n"
                connection.send(content: Data(ack.utf8), completion: .contentProcessed { _ in })
                connection.cancel()
                fail()
                return
            }
        }

        while buffer.count >= 4 {
            let bytes = [UInt8](buffer.prefix(4))
            let count = Int(UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24)
            guard count > 0, count <= 48_000 else {
                fail()
                connection.cancel()
                return
            }
            let needed = 4 + count * 2
            guard buffer.count >= needed else { return }
            let pcm = buffer.subdata(in: 4..<needed)
            buffer.removeSubrange(0..<needed)
            let payload = [UInt8](pcm)
            var samples = [Double](repeating: 0, count: count)
            for i in 0..<count {
                let lo = UInt16(payload[i * 2])
                let hi = UInt16(payload[i * 2 + 1])
                let combined = Int16(bitPattern: lo | (hi << 8))
                samples[i] = Double(combined) / 32767.0
            }
            onPCM(samples)
        }
    }
}

extension HydrophoneHello {
    nonisolated static func decode(_ data: Data) throws -> HydrophoneHello {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let eventsJSON = object["events"] as? [[String: Any]] ?? []
        let events: [GroundTruthWire] = eventsJSON.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return GroundTruthWire(
                id: id,
                tOnsetSeconds: (row["tOnsetSeconds"] as? NSNumber)?.doubleValue ?? 0,
                tOffsetSeconds: (row["tOffsetSeconds"] as? NSNumber)?.doubleValue,
                label: row["label"] as? String ?? "",
                expectedAlert: row["expectedAlert"] as? Bool ?? false,
                sourceClipId: row["sourceClipId"] as? String ?? "",
                notes: row["notes"] as? String
            )
        }
        return HydrophoneHello(
            hydrophoneId: object["hydrophoneId"] as? String ?? UUID().uuidString,
            hydrophoneName: object["hydrophoneName"] as? String ?? "Hydrophone 1",
            siteName: object["siteName"] as? String ?? "Indonesia N1",
            sampleRate: (object["sampleRate"] as? NSNumber)?.doubleValue ?? PipelineConstants.sampleRate,
            channels: (object["channels"] as? NSNumber)?.intValue ?? 1,
            scenarioId: object["scenarioId"] as? String ?? "unknown",
            scenarioName: object["scenarioName"] as? String ?? "Scenario",
            source: object["source"] as? String ?? "simulator",
            construction: object["construction"] as? String ?? "distribution_sample",
            durationSeconds: (object["durationSeconds"] as? NSNumber)?.doubleValue ?? 0,
            latitude: (object["latitude"] as? NSNumber)?.doubleValue,
            longitude: (object["longitude"] as? NSNumber)?.doubleValue,
            events: events
        )
    }
}
