import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var detectionStore: DetectionStore
    @EnvironmentObject private var hydrophoneHub: HydrophoneHub
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query(sort: \Site.createdAt, order: .reverse) private var sites: [Site]
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse)
    private var alertEvents: [BlastDetectionEvent]

    @State private var selection: SidebarDestination? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPresentingNewSite = false
    @State private var sitePendingDeletion: Site?
    @State private var isConfirmingSiteDeletion = false
    @State private var isAtStartPage = true
    @State private var selectionBeforeAlert: SidebarDestination?

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                onBoardingView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasCompletedOnboarding = true
                    }
                }
            } else if isAtStartPage {
                StartPageView(
                    sites: sites,
                    onSelectSite: { site in
                        selection = .site(site.id)
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
        .onChange(of: selection) { _, newSelection in
            if let newSelection, case .alert = newSelection {
                return
            }
            selectionBeforeAlert = nil
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
                    selection: $selection,
                    onAddSite: presentNewSite,
                    onDeleteSite: confirmDeleteSite
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("")
            }

            if isPresentingNewSite {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismissNewSite)

                SiteFormOverlay(
                    onCancel: dismissNewSite,
                    onSubmit: createSite
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPresentingNewSite)
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
        switch selection ?? .home {
        case .home:
            SiteHomeView(
                sites: sites,
                onAddSite: presentNewSite,
                onViewAllAlerts: { selection = .alerts },
                onSelectAlert: { showAlert($0) }
            )

        case .sites:
            if let site = sites.first {
                sitesWorkspace(selectedSite: site)
            } else {
                SiteHomeView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { selection = .alerts },
                    onSelectAlert: { showAlert($0) }
                )
            }

#if DEBUG
        case .simulator:
            SimulatorView()
#endif

        case .alerts:
            AlertsWorkspace(
                scope: .all,
                onSelectAlert: { showAlert($0) }
            )

        case .siteAlerts(let siteID):
            if let site = sites.first(where: { $0.id == siteID }) {
                AlertsWorkspace(
                    scope: .site(name: site.name),
                    onSelectAlert: { showAlert($0) }
                )
            } else {
                SiteHomeView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { selection = .alerts },
                    onSelectAlert: { showAlert($0) }
                )
            }

        case .alert(let alertID):
            if let alert = alertEvents.first(where: { $0.id == alertID }) {
                AlertDetailView(
                    event: alert,
                    sites: sites,
                    onBack: dismissAlertDetail
                )
            } else {
                SiteHomeView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { selection = .alerts },
                    onSelectAlert: { showAlert($0) }
                )
            }

        case .site(let siteID):
            if let site = sites.first(where: { $0.id == siteID }) {
                sitesWorkspace(selectedSite: site)
            } else {
                SiteHomeView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { selection = .alerts },
                    onSelectAlert: { showAlert($0) }
                )
            }
        }
    }

    private func sitesWorkspace(selectedSite: Site) -> some View {
        SitesWorkspaceView(
            site: selectedSite,
            onAddSite: presentNewSite,
            onDeleteSite: deleteSiteFromSettings,
            onViewSiteAlerts: { selection = .siteAlerts(selectedSite.id) },
            onSelectAlert: { showAlert($0) }
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
        selection = .site(site.id)
        dismissNewSite()
    }

    private func confirmDeleteSite(_ site: Site) {
        sitePendingDeletion = site
        isConfirmingSiteDeletion = true
    }

    private func deletePendingSite() {
        guard let sitePendingDeletion else { return }

        if selection == .site(sitePendingDeletion.id) {
            selection = .sites
        }

        modelContext.delete(sitePendingDeletion)
        self.sitePendingDeletion = nil
    }

    private func deleteSiteFromSettings(_ site: Site) {
        if selection == .site(site.id)
            || selection == .siteAlerts(site.id)
            || selection == .sites {
            selection = .home
        }
        modelContext.delete(site)
    }

    private func showAlert(_ alert: BlastDetectionEvent) {
        if let selection, case .alert = selection {
            // Preserve the original screen so Back still returns to it.
        } else {
            selectionBeforeAlert = selection
        }
        selection = .alert(alert.id)
    }

    private func dismissAlertDetail() {
        let destination = selectionBeforeAlert ?? .home
        selectionBeforeAlert = nil
        selection = destination
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
    ContentView()
        .environmentObject(DetectionStore())
        .environmentObject(HydrophoneHub())
        .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
}
