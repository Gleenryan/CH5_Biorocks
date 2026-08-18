import SwiftUI
import SwiftData

struct SitesWorkspaceView: View {
    let site: Site
    let onAddSite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            SiteDetailView(site: site)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sites")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Monitor and manage reef Sites and their hydrophones.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onAddSite) {
                Label("Add Site", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

#Preview {
    let site = Site(
        name: "Simulator Reef",
        startLatitude: -8.1287,
        startLongitude: 114.6608,
        endLatitude: -8.1322,
        endLongitude: 114.6715
    )

    SitesWorkspaceView(site: site, onAddSite: {})
        .environmentObject(DetectionStore())
        .environmentObject(HydrophoneHub())
        .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
        .frame(width: 1_200, height: 800)
}
