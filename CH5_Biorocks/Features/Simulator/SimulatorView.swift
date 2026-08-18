import SwiftUI
import SwiftData

struct SimulatorView: View {
    @EnvironmentObject private var store: DetectionStore
    @EnvironmentObject private var hub: HydrophoneHub

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusRow
                howToRun
                liveHydrophones
                scorecard
                stageLog
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Simulator")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Python pretends to be hydrophones. This Mac runs Model 1, Core ML Model 2, debounce, health indices, and Foundation Models.")
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
                title: "Foundation Models",
                value: FoundationModelNarrator.isAvailable ? "Available" : "Template fallback",
                ok: FoundationModelNarrator.isAvailable
            )
            StatusChip(
                title: "Threshold",
                value: String(format: "%.3f", PipelineConstants.blastThreshold),
                ok: true
            )
        }
    }

    private var howToRun: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Python hydrophone")
                .font(.headline)
            Text("From blast-synth-ml, with the app running:")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(".venv/bin/python -m src.sim.hydrophone_sim --fleet --realtime")
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            Text("Single hydrophone: --scenario blast_in_ambient --realtime. --fleet streams Simulator Reef (blast), Amed, Nusa Penida, and Tulamben at once.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }

    private var liveHydrophones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected hydrophones")
                .font(.headline)
            if store.liveHydrophones.isEmpty {
                Text("Waiting for a Python simulator connection.")
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
                Text("Model 1 / Model 2 / debounce lines appear here while a hydrophone is streaming.")
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

private struct SimulatorHydrophoneCard: View {
    let hydro: LiveHydrophoneStatus

    @EnvironmentObject private var store: DetectionStore
    @EnvironmentObject private var hub: HydrophoneHub
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse) private var events: [BlastDetectionEvent]

    private var isListening: Bool {
        store.listeningHydrophoneID == hydro.id
    }

    private var hasBlast: Bool {
        events.contains {
            $0.hydrophoneId.caseInsensitiveCompare(hydro.id) == .orderedSame
                || (
                    $0.hydrophoneName.localizedCaseInsensitiveCompare(hydro.name) == .orderedSame
                        && $0.siteName.localizedCaseInsensitiveCompare(hydro.siteName) == .orderedSame
                )
        }
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
