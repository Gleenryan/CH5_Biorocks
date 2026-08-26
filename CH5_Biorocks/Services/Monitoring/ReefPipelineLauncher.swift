import Combine
import Darwin
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
                // 2 = SIGINT, 9 = SIGKILL, 15 = SIGTERM — expected Stop outcomes.
                if proc.terminationStatus != 0 && ![2, 9, 15].contains(Int(proc.terminationStatus)) {
                    self?.lastError = "Simulator exited with code \(proc.terminationStatus)"
                }
                onLog("reef_pipeline stopped (status \(proc.terminationStatus))")
            }
        }

        do {
            try process.run()
            let pid = process.processIdentifier
            if pid > 0 {
                _ = setpgid(pid, pid)
            }
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
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        isRunning = false
        guard let process else { return }
        killProcessTree(process)
        let captured = process
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if captured.isRunning {
                Self.forceKill(captured)
            }
            await MainActor.run {
                if self?.process === captured {
                    self?.process = nil
                }
            }
        }
    }

    deinit {
        if let process, process.isRunning {
            Self.forceKill(process)
        }
    }

    private func killProcessTree(_ process: Process) {
        let pid = process.processIdentifier
        if pid > 0 {
            for child in Self.descendantPIDs(of: pid) {
                kill(child, SIGTERM)
            }
            kill(pid, SIGINT)
            kill(pid, SIGTERM)
            _ = kill(-pid, SIGTERM)
        } else {
            process.interrupt()
            process.terminate()
        }
    }

    nonisolated private static func forceKill(_ process: Process) {
        let pid = process.processIdentifier
        if pid > 0 {
            for child in descendantPIDs(of: pid) {
                kill(child, SIGKILL)
            }
            kill(pid, SIGKILL)
            _ = kill(-pid, SIGKILL)
        }
        if process.isRunning {
            process.terminate()
        }
    }

    nonisolated private static func descendantPIDs(of pid: Int32) -> [Int32] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-P", String(pid)]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.split(whereSeparator: \.isNewline).compactMap { Int32($0) }
    }
}
