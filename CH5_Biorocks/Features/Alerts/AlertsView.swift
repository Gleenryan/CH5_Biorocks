import SwiftUI
import SwiftData

struct AlertsView: View {
    var siteName: String? = nil
    var onSelectAlert: (BlastDetectionEvent) -> Void = { _ in }

    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse)
    private var events: [BlastDetectionEvent]

    private var filtered: [BlastDetectionEvent] {
        guard let siteName else { return events }
        return events.filter { $0.siteName == siteName }
    }

    var body: some View {
        if filtered.isEmpty {
            ContentUnavailableView {
                Label("No Blast Alerts", systemImage: "bell.slash")
            } description: {
                Text("Promoted detections from the live hydrophone pipeline will appear here. Simulator events are tagged source=simulator.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .siteGlassCard(cornerRadius: 18)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filtered) { event in
                        Button {
                            onSelectAlert(event)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(event.siteName)
                                        .font(.headline)
                                    Spacer()
                                    Text(event.severity.uppercased())
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(severityColor(event.severity))
                                        .padding(.horizontal, 8)
                                        .frame(height: 22)
                                        .background(severityColor(event.severity).opacity(0.12), in: Capsule())
                                }
                                Text(event.onsetTime.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(event.hydrophoneName) · P(blast) \(event.pBlast.formatted(.number.precision(.fractionLength(3)))) · \(event.source)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(event.narrative)
                                    .font(.callout)
                                if event.narrativeSource == "template" {
                                    Text("Foundation Models unavailable — templated fallback")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .siteGlassCard(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open alert details")
                    }
                }
                .padding(4)
            }
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "high": .red
        case "medium": .orange
        default: .yellow
        }
    }
}
