import SwiftUI
import SwiftData

struct SitesWorkspaceView: View {
    let site: Site
    let onAddSite: () -> Void
    let onDeleteSite: (Site) -> Void
    let onViewSiteAlerts: () -> Void
    let onSelectAlert: (BlastDetectionEvent) -> Void

    var body: some View {
        SiteDetailView(
            site: site,
            onDeleteSite: onDeleteSite,
            onViewSiteAlerts: onViewSiteAlerts,
            onSelectAlert: onSelectAlert
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color(nsColor: .windowBackgroundColor))
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

    SitesWorkspaceView(
        site: site,
        onAddSite: {},
        onDeleteSite: { _ in },
        onViewSiteAlerts: {},
        onSelectAlert: { _ in }
    )
        .environmentObject(DetectionStore())
        .environmentObject(HydrophoneHub())
        .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
        .frame(width: 1_200, height: 800)
}
