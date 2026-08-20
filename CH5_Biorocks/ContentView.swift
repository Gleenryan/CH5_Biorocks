import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var detectionStore: DetectionStore
    @EnvironmentObject private var hydrophoneHub: HydrophoneHub
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query(sort: \Site.createdAt, order: .reverse) private var sites: [Site]

    @State private var selection: SidebarDestination? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPresentingNewSite = false
    @State private var sitePendingDeletion: Site?
    @State private var isConfirmingSiteDeletion = false
    @State private var isAtStartPage = true

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
                onViewAllAlerts: { selection = .alerts }
            )

        case .sites:
            if let site = sites.first {
                sitesWorkspace(selectedSite: site)
            } else {
                SiteHomeView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { selection = .alerts }
                )
            }

#if DEBUG
        case .simulator:
            SimulatorView()
#endif

        case .alerts:
            AlertsWorkspace()

        case .site(let siteID):
            if let site = sites.first(where: { $0.id == siteID }) {
                sitesWorkspace(selectedSite: site)
            } else {
                SiteHomeView(
                    sites: sites,
                    onAddSite: presentNewSite,
                    onViewAllAlerts: { selection = .alerts }
                )
            }
        }
    }

    private func sitesWorkspace(selectedSite: Site) -> some View {
        SitesWorkspaceView(
            site: selectedSite,
            onAddSite: presentNewSite
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
}

private struct AlertsWorkspace: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Alerts")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Blast detections promoted after Model 1, Model 2, and debounce. Simulator events stay tagged as simulator.")
                .font(.callout)
                .foregroundStyle(.secondary)
            AllAlertsView()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(DetectionStore())
        .environmentObject(HydrophoneHub())
        .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self, HealthSnapshotRecord.self], inMemory: true)
}
