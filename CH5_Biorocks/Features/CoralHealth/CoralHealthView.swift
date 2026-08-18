import SwiftUI
import SwiftData
import Charts

struct CoralHealthView: View {
    var siteName: String?

    @Query(sort: \HealthSnapshotRecord.windowStart, order: .reverse)
    private var snapshots: [HealthSnapshotRecord]

    private var filtered: [HealthSnapshotRecord] {
        guard let siteName else { return snapshots }
        return snapshots.filter { $0.siteName == siteName }
    }

    var body: some View {
        if filtered.isEmpty {
            ContentUnavailableView {
                Label("No Coral Health Data", systemImage: "waveform.path.ecg")
            } description: {
                Text("Acoustic-index snapshots are computed from hydrophone audio every minute (or once per short simulator run). This is an unsupervised composite, not a trained healthy/degraded classifier.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .siteGlassCard(cornerRadius: 18)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let latest = filtered.first {
                        latestCard(latest)
                    }
                    if filtered.count > 1 {
                        trendCard
                    }
                    ForEach(filtered.prefix(12)) { snap in
                        historyRow(snap)
                    }
                }
                .padding(4)
            }
        }
    }

    private func latestCard(_ snap: HealthSnapshotRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Acoustic composite")
                    .font(.headline)
                Spacer()
                Text(snap.healthClass)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            Text(String(format: "%.0f / 100", snap.healthScore))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
            Text(snap.note)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(snap.narrative)
                .font(.callout)
            if snap.narrativeSource == "template" {
                Text("Foundation Models unavailable — templated fallback")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                metric("NDSI", String(format: "%.2f", snap.ndsi))
                metric("ADI", String(format: "%.2f", snap.adi))
                metric("AEI", String(format: "%.2f", snap.aei))
                metric("Snaps / min", String(format: "%.0f", snap.snapRatePerMin))
                metric("Low-freq dBFS", String(format: "%.1f", snap.lowFreqSPL_dB))
                metric("Blasts / hour", "\(snap.blastEventCountLastHour)")
            }
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Composite over time")
                .font(.headline)
            Chart(Array(filtered.prefix(20).reversed()), id: \.id) { snap in
                LineMark(
                    x: .value("Time", snap.windowStart),
                    y: .value("Score", snap.healthScore)
                )
                .foregroundStyle(Color.accentColor)
            }
            .frame(height: 160)
        }
        .padding(16)
        .siteGlassCard(cornerRadius: 16)
    }

    private func historyRow(_ snap: HealthSnapshotRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.hydrophoneName)
                    .font(.callout.weight(.medium))
                Text(snap.windowStart.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(format: "%.0f", snap.healthScore))
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(12)
        .siteGlassCard(cornerRadius: 12)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
