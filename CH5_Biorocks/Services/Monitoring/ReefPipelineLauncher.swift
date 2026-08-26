import Combine
import Foundation

/// Launches the vendored `reef_pipeline` Python hydrophone simulator.
@MainActor
final class ReefPipelineLauncher: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        /// Beach / sea exhibition window + fleet into the app (default Start).
        case exhibit = "Exhibition scene"
        case stream = "Fleet only"
        case streamTwoBlasts = "Fleet · 2 blasts"

        var id: String { rawValue }

        var arguments: [String] {
            let seed = String(Int(Date().timeIntervalSince1970) % 10_000)
            switch self {
            case .exhibit:
                return ["exhibit", "--n-blasts", "1", "--seed", seed, "--loop", "--max-seconds", "45"]
            case .stream:
                return ["stream", "--fleet", "--realtime", "--n-blasts", "1", "--seed", seed]
            case .streamTwoBlasts:
                return ["stream", "--fleet", "--realtime", "--n-blasts", "2", "--seed", seed]
            }
        }

        var opensExhibitionWindow: Bool { self == .exhibit }
    }

    @Published private(set) var isRunning = false
    @Published private(set) var lastOutput = ""
    @Published private(set) var lastError: String?
    /// Start simulator opens the beach exhibition scene by default.
    @Published var selectedMode: Mode = .exhibit

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    var pythonDirectory: URL {
        // Prefer sibling Python/ next to the .xcodeproj (dev checkout).
        let projectPython = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Monitoring
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // CH5_Biorocks
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Python", isDirectory: true)
        if FileManager.default.fileExists(atPath: projectPython.path) {
            return projectPython
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/CH5_Biorocks/Python", isDirectory: true)
    }

    var rawDataDirectory: URL {
        if let env = ProcessInfo.processInfo.environment["REEFGUARD_RAW_DATA"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/CH5/raw-data", isDirectory: true)
    }

    func pythonExecutable() -> URL? {
        let venv = pythonDirectory.appendingPathComponent(".venv/bin/python")
        if FileManager.default.isExecutableFile(atPath: venv.path) {
            return venv
        }
        let candidates = ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    var setupHint: String {
        """
        cd \(pythonDirectory.path)
        python3 -m venv .venv
        .venv/bin/pip install -r requirements.txt
        export REEFGUARD_RAW_DATA="\(rawDataDirectory.path)"
        """
    }

    func start(mode: Mode? = nil, onLog: @escaping (String) -> Void) {
        stop()
        let mode = mode ?? selectedMode
        selectedMode = mode
        guard let python = pythonExecutable() else {
            lastError = "Python not found. Create Python/.venv first."
            onLog(lastError ?? "")
            return
        }

        let process = Process()
        process.executableURL = python
        process.arguments = ["-m", "reef_pipeline"] + mode.arguments
        process.currentDirectoryURL = pythonDirectory

        var env = ProcessInfo.processInfo.environment
        env["REEFGUARD_RAW_DATA"] = rawDataDirectory.path
        env["PYTHONUNBUFFERED"] = "1"
        env["NUMBA_DISABLE_JIT"] = "1"
        if mode.opensExhibitionWindow {
            // Force a real macOS window when started from the Coralyst Start button.
            env["MPLBACKEND"] = "MacOSX"
        }
        process.environment = env

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        outputPipe = out
        errorPipe = err

        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            Task { @MainActor in
                self.lastOutput += text
                onLog(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        err.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            Task { @MainActor in
                self.lastOutput += text
                onLog(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.isRunning = false
                self?.process = nil
                if proc.terminationStatus != 0 && proc.terminationStatus != 15 {
                    self?.lastError = "Simulator exited with code \(proc.terminationStatus)"
                }
                onLog("reef_pipeline stopped (status \(proc.terminationStatus))")
            }
        }

        do {
            try process.run()
            self.process = process
            isRunning = true
            lastError = nil
            lastOutput = ""
            onLog("Started \(mode.rawValue): \(mode.arguments.joined(separator: " "))")
        } catch {
            lastError = error.localizedDescription
            onLog("Failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let process else { return }
        process.terminate()
        self.process = nil
        isRunning = false
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
    }
}
