//
//  ContentView.swift
//  CH5_Biorocks
//
//  Created by Gleenryan on 11/08/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeededRequestedDemoSitesV1") private var hasSeededRequestedDemoSites = false
    @Query(sort: \Site.createdAt, order: .reverse) private var sites: [Site]

    @State private var selection: SidebarDestination? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPresentingNewSite = false
    @State private var sitePendingDeletion: Site?
    @State private var isConfirmingSiteDeletion = false
    @State private var demoSeedErrorMessage = ""
    @State private var isShowingDemoSeedError = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                applicationShell
            } else {
                onBoardingView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasCompletedOnboarding = true
                        selection = .home
                    }
                }
            }
        }
        .frame(minWidth: 840, minHeight: 620)
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
        .task {
            seedRequestedDemoSitesIfNeeded()
        }
        .confirmationDialog(
            "Delete \(sitePendingDeletion?.name ?? "Site")?",
            isPresented: $isConfirmingSiteDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Site", role: .destructive, action: deletePendingSite)
        } message: {
            Text("The Site and all of its hydrophones will be permanently removed.")
        }
        .alert("Demo Data Could Not Be Added", isPresented: $isShowingDemoSeedError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(demoSeedErrorMessage)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .home {
        case .home:
            SiteHomeView(sites: sites, onAddSite: presentNewSite)

        case .sites:
            if let site = sites.first {
                sitesWorkspace(selectedSite: site)
            } else {
                SiteHomeView(sites: sites, onAddSite: presentNewSite)
            }

        case .microphones:
            microphoneView()

        case .site(let siteID):
            if let site = sites.first(where: { $0.id == siteID }) {
                sitesWorkspace(selectedSite: site)
            } else {
                SiteHomeView(sites: sites, onAddSite: presentNewSite)
            }
        }
    }

    private func sitesWorkspace(selectedSite: Site) -> some View {
        SitesWorkspaceView(
            sites: sites,
            selectedSite: selectedSite,
            onSelectSite: { site in
                selection = .site(site.id)
            },
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

    private func seedRequestedDemoSitesIfNeeded() {
        guard !hasSeededRequestedDemoSites else { return }

        do {
            try DemoSiteSeeder.seedMissingSites(
                into: modelContext,
                existingSites: sites
            )
            hasSeededRequestedDemoSites = true
        } catch {
            demoSeedErrorMessage = error.localizedDescription
            isShowingDemoSeedError = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Site.self, CustomLocation.self], inMemory: true)
}
