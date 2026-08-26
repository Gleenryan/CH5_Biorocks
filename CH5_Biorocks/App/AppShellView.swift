import SwiftUI
import SwiftData

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var detectionStore: DetectionStore
    @EnvironmentObject private var hydrophoneHub: HydrophoneHub
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query(sort: \Site.createdAt, order: .reverse) private var sites: [Site]
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse)
    private var alertEvents: [BlastDetectionEvent]

    @StateObject private var router = AppRouter()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPresentingNewSite = false
    @State private var sitePendingDeletion: Site?
    @State private var isConfirmingSiteDeletion = false
    @State private var isAtStartPage = true

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasCompletedOnboarding = true
                    }
                }
            } else if isAtStartPage {
                StartPageView(
                    sites: sites,
                    onSelectSite: { site in
                        router.selection = .site(site.id)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isAtStartPage = false
                        }
                    },
                    onCreateSite: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isAtStartPage = false
                        }
                        presentNewSite()
                    }
                )
            } else {
                applicationShell
            }
        }
        .frame(minWidth: 840, minHeight: 620)
        .onChange(of: router.selection) { _, newSelection in
            router.noteSelectionChange(to: newSelection)
        }
        .task {
#if DEBUG
            SimulatorCatalog.bootstrap(modelContext: modelContext)
#endif
            detectionStore.attach(modelContext: modelContext)
            hydrophoneHub.attach(store: detectionStore)
#if DEBUG
            hydrophoneHub.start()
#endif
        }
    }

    private var applicationShell: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(
                    sites: sites,
                    selection: $router.selection,
                    onAddSite: presentNewSite,
                    onDeleteSite: confirmDeleteSite
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("")
            }
            .blur(radius: isPresentingNewSite ? 8 : 0)

            if isPresentingNewSite {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.25))
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismissNewSite)

                SiteFormOverlay(
                    onCancel: dismissNewSite,
                    onSubmit: createSite
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .shadow(color: .black.opacity(0.24), radius: 26, y: 12)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPresentingNewSite)
        .confirmationDialog(
            "Delete \(sitePendingDeletion?.name ?? "Site")?",
            isPresented: $isConfirmingSiteDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Site", role: .destructive, action: deletePendingSite)
        } message: {
            Text("The Site and all of its hydrophones will be permanently removed.")
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch router.selection ?? .home {
        case .home:
            DashboardView(
                sites: sites,
                onAddSite: presentNewSite,
                onViewAllAlerts: { router.selection = .alerts },
                onSelectAlert: { router.showAlert($0) }
            )

        case .sites:
            if let site = sites.first {
                sitesWorkspace(selectedSite: site)
            } else {
                DashboardView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { router.selection = .alerts },
                    onSelectAlert: { router.showAlert($0) }
                )
            }

#if DEBUG
        case .simulator:
            SimulatorView()
#endif

        case .alerts:
            AlertsWorkspace(
                scope: .all,
                onSelectAlert: { router.showAlert($0) }
            )

        case .siteAlerts(let siteID):
            if let site = sites.first(where: { $0.id == siteID }) {
                AlertsWorkspace(
                    scope: .site(name: site.name),
                    onSelectAlert: { router.showAlert($0) }
                )
            } else {
                DashboardView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { router.selection = .alerts },
                    onSelectAlert: { router.showAlert($0) }
                )
            }

        case .alert(let alertID):
            if let alert = alertEvents.first(where: { $0.id == alertID }) {
                AlertDetailView(
                    event: alert,
                    sites: sites,
                    onBack: router.dismissAlertDetail
                )
            } else {
                DashboardView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { router.selection = .alerts },
                    onSelectAlert: { router.showAlert($0) }
                )
            }

        case .site(let siteID):
            if let site = sites.first(where: { $0.id == siteID }) {
                sitesWorkspace(selectedSite: site)
            } else {
                DashboardView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { router.selection = .alerts },
                    onSelectAlert: { router.showAlert($0) }
                )
            }
        }
    }

    private func sitesWorkspace(selectedSite: Site) -> some View {
        SitesWorkspaceView(
            site: selectedSite,
            onAddSite: presentNewSite,
            onDeleteSite: deleteSiteFromSettings,
            onViewSiteAlerts: { router.selection = .siteAlerts(selectedSite.id) },
            onSelectAlert: { router.showAlert($0) }
        )
    }

    private func presentNewSite() {
        isPresentingNewSite = true
    }

    private func dismissNewSite() {
        isPresentingNewSite = false
    }

    private func createSite(
        name: String,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double
    ) {
        let site = Site(
            name: name,
            startLatitude: startLatitude,
            startLongitude: startLongitude,
            endLatitude: endLatitude,
            endLongitude: endLongitude
        )

        modelContext.insert(site)
        router.selection = .site(site.id)
        dismissNewSite()
    }

    private func confirmDeleteSite(_ site: Site) {
        sitePendingDeletion = site
        isConfirmingSiteDeletion = true
    }

    private func deletePendingSite() {
        guard let sitePendingDeletion else { return }

        if router.selection == .site(sitePendingDeletion.id) {
            router.selection = .sites
        }

        modelContext.delete(sitePendingDeletion)
        self.sitePendingDeletion = nil
    }

    private func deleteSiteFromSettings(_ site: Site) {
        if router.selection == .site(site.id)
            || router.selection == .siteAlerts(site.id)
            || router.selection == .sites {
            router.selection = .home
        }
        modelContext.delete(site)
    }

}

private struct AlertsWorkspace: View {
    let scope: AlertListScope
    let onSelectAlert: (BlastDetectionEvent) -> Void

    var body: some View {
        AlertsView(scope: scope, onSelectAlert: onSelectAlert)
    }
}

#Preview {
    AppShellView()
        .environmentObject(DetectionStore())
        .environmentObject(HydrophoneHub())
        .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
}
