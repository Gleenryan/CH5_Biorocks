import SwiftUI
import SwiftData

struct SimulatorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: DetectionStore
    @EnvironmentObject private var hub: HydrophoneHub
    @StateObject private var launcher = ReefPipelineLauncher()
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse) private var events: [BlastDetectionEvent]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                simulatorColumn
                    .frame(minWidth: 420, idealWidth: 560, maxWidth: 720)
                Divider()
                resultsColumn
                    .frame(minWidth: 360, maxWidth: .infinity)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusRow
                    launchPanel
                    liveHydrophones
                    resultsBody
                    stageLog
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var simulatorColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusRow
                launchPanel
                liveHydrophones
                stageLog
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private var resultsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                resultsHeader
                resultsBody
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Simulator")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(headerBlurb)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var headerBlurb: String {
        if launcher.selectedMode.opensExhibitionWindow {
            return "Start simulator opens the beach scene with four hydrophones and a blast event. That window streams into this app at the same time — detections appear here on the right."
        }
        return "Four hydrophones on Indonesia N1 stream real dataset WAVs. Exactly one hydro gets a blast clip mixed in; the other three are normal field audio only. BLAST badges appear only if Core ML detects a blast on that hydro."
    }

    private var resultsHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live results")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Core ML detections land here while the simulator is running. Put the beach scene beside this window for the exhibition.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            StatusChip(
                title: "Core ML",
                value: store.classifierReady ? "Ready" : "Missing",
                ok: store.classifierReady
            )
            StatusChip(
                title: "Hydrophone port",
                value: store.serverReady ? "127.0.0.1:\(Int(PipelineConstants.listenPort))" : (store.serverError ?? "Starting"),
                ok: store.serverReady
            )
            StatusChip(
                title: "reef_pipeline",
                value: launcher.isRunning ? (launcher.selectedMode.opensExhibitionWindow ? "Exhibit" : "Streaming") : (launcher.pythonExecutable() != nil ? "Ready" : "Setup needed"),
                ok: launcher.pythonExecutable() != nil
            )
            StatusChip(
                title: "Threshold",
                value: String(format: "%.3f", PipelineConstants.blastThreshold),
                ok: true
            )
        }
    }

    private var launchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start simulator")
                .font(.headline)

            Picker("Mode", selection: $launcher.selectedMode) {
                ForEach(ReefPipelineLauncher.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(launcher.isRunning)

            Text(
                launcher.selectedMode.opensExhibitionWindow
                    ? "Opens the beach / sea scene and streams the four hydrophones into this app."
                    : "Streams fleet audio into the app without the exhibition window."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    SimulatorCatalog.clearSiteAlerts(modelContext: modelContext)
                    launcher.start { line in
                        guard !line.isEmpty else { return }
                        store.appendLog(
                            PipelineLogLine(
                                hydrophoneName: "reef_pipeline",
                                stage: "Python",
                                detail: String(line.prefix(240))
                            )
                        )
                    }
                } label: {
                    Label(
                        launcher.isRunning
                            ? (launcher.selectedMode.opensExhibitionWindow ? "Simulator live…" : "Streaming…")
                            : "Start simulator",
                        systemImage: launcher.selectedMode.opensExhibitionWindow ? "wave.3.right" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(launcher.isRunning || !store.serverReady)

                Button {
                    launcher.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!launcher.isRunning)
            }

            if let error = launcher.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if launcher.pythonExecutable() == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Python venv not found. Run once in Terminal:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(launcher.setupHint)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Text("Data root: \(launcher.rawDataDirectory.path)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var resultsBody: some View {
        liveDetections
        soundDetails
        scorecard
    }

    private var liveDetections: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Blast detections")
                    .font(.headline)
                Spacer()
                Text("\(events.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(launcher.isRunning ? "Listening… waiting for Core ML to promote a blast." : "No detections yet. Press Start simulator.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LivePulseBanner(active: launcher.isRunning && !store.liveHydrophones.isEmpty)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(events.prefix(8)) { event in
                    AlertCard(alert: AlertSummary(event: event), primaryText: .primary)
                }
            }
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var soundDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sound details")
                .font(.headline)
            if let health = store.lastHealth {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    SoundMetric(title: "Health", value: String(format: "%.0f · %@", health.healthScore, health.healthClass))
                    SoundMetric(title: "Snap / min", value: String(format: "%.1f", health.indices.snapRatePerMin))
                    SoundMetric(title: "SPL low (dB)", value: String(format: "%.1f", health.indices.lowFreqSPL_dB))
                    SoundMetric(title: "NDSI", value: String(format: "%.3f", health.indices.ndsi))
                    SoundMetric(title: "ADI", value: String(format: "%.3f", health.indices.adi))
                    SoundMetric(title: "AEI", value: String(format: "%.3f", health.indices.aei))
                    SoundMetric(title: "ACI", value: String(format: "%.1f", health.indices.aci))
                    SoundMetric(title: "Biophony", value: String(format: "%.2f", health.indices.biophonyRatio))
                    SoundMetric(title: "Anthrophony", value: String(format: "%.2f", health.indices.anthrophonyRatio))
                    SoundMetric(title: "Blasts (1h)", value: "\(health.blastEventCountLastHour)")
                }
                if !health.note.isEmpty {
                    Text(health.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sound indices appear after a hydrophone has streamed for about a minute (health window).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }

    private var liveHydrophones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected hydrophones")
                .font(.headline)
            if store.liveHydrophones.isEmpty {
                Text("Start a stream above, or wait for a Python hydrophone connection.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.liveHydrophones) { hydro in
                    SimulatorHydrophoneCard(hydro: hydro)
                }
            }
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var scorecard: some View {
        if let card = store.lastScorecard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last scenario scorecard")
                    .font(.headline)
                Text(card.scenarioId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    ScoreStat(title: "TP", value: "\(card.tp)")
                    ScoreStat(title: "FN", value: "\(card.fn)")
                    ScoreStat(title: "FP", value: "\(card.fp)")
                    ScoreStat(title: "Recall", value: String(format: "%.0f%%", card.recall * 100))
                    ScoreStat(title: "Precision", value: String(format: "%.0f%%", card.precision * 100))
                }
            }
            .padding(16)
            .siteGlassCard(cornerRadius: 16)
        }
    }

    private var stageLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pipeline log")
                .font(.headline)
            if store.log.isEmpty {
                Text("Connect / gate / classify / alert lines appear here while a hydrophone is streaming.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.log.prefix(40)) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Text(line.stage)
                            .font(.caption.weight(.semibold))
                            .frame(width: 72, alignment: .leading)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.detail)
                                .font(.caption)
                            Text("\(line.hydrophoneName) · \(line.timestamp.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }
}

private struct LivePulseBanner: View {
    let active: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(active ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)
                .scaleEffect(active && pulse ? 1.35 : 1.0)
                .opacity(active && pulse ? 0.55 : 1.0)
                .animation(
                    active ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )
            Text(active ? "Fleet audio arriving · watching for impulse + Core ML promote" : "Idle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { pulse = active }
        .onChange(of: active) { _, newValue in
            pulse = newValue
        }
    }
}

private struct SoundMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SimulatorHydrophoneCard: View {
    let hydro: LiveHydrophoneStatus

    @EnvironmentObject private var store: DetectionStore
    @EnvironmentObject private var hub: HydrophoneHub
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse) private var events: [BlastDetectionEvent]

    private var isListening: Bool {
        store.listeningHydrophoneID == hydro.id
    }

    /// BLAST badge only when this hydrophone actually has a stored detection (by id).
    private var hasBlast: Bool {
        let id = hydro.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !id.isEmpty else { return false }
        return events.contains { event in
            let eventID = normalizedHydrophoneID(event.hydrophoneId)
            return eventID == id
        }
    }

    private func normalizedHydrophoneID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("sim://") {
            return String(trimmed.dropFirst(6))
        }
        return trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(hydro.connected ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(hydro.name).font(.callout.weight(.semibold))
                        if hasBlast {
                            Text("BLAST")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.red)
                                .padding(.horizontal, 6)
                                .frame(height: 16)
                                .background(Color.red.opacity(0.16), in: Capsule())
                        }
                    }
                    Text("\(hydro.siteName) · \(hydro.scenarioName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(hydro.connected ? String(format: "rms %.3f", hydro.lastRMS) : "idle")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                listenButton
            }

            LiveWaveformView(
                samples: store.envelope(for: hydro.id),
                isLive: hydro.connected
            )
            .frame(height: 56)

            Text(hydro.connected ? "Live scene audio is playing through this hydrophone." : "Stream ended. Replay the clip attached to this hydrophone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var listenButton: some View {
        if hydro.connected {
            Button {
                hub.toggleListen(hydrophoneID: hydro.id)
            } label: {
                Label(isListening ? "Listening" : "Listen", systemImage: isListening ? "speaker.wave.2.fill" : "speaker.wave.2")
            }
            .buttonStyle(.bordered)
            .tint(isListening ? .green : .accentColor)
            .controlSize(.small)
        } else if store.hasClip[hydro.id] == true {
            Button {
                hub.replay(hydrophoneID: hydro.id)
            } label: {
                Label("Replay", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct StatusChip: View {
    let title: String
    let value: String
    let ok: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ok ? Color.primary : Color.red)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .siteGlassCard(cornerRadius: 12)
    }
}

private struct ScoreStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
