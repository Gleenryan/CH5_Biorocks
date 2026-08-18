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
    @Query(sort: \Site.createdAt, order: .reverse) private var sites: [Site]

    @State private var selection: SidebarDestination? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPresentingNewSite = false
    @State private var sitePendingDeletion: Site?
    @State private var isConfirmingSiteDeletion = false

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
            SiteHomeView(sites: sites, onAddSite: presentNewSite)

        case .alerts:
            AlertsPlaceholderView()

        case .microphones:
            microphoneView()

        case .site(let siteID):
            if let site = sites.first(where: { $0.id == siteID }) {
                SiteDetailView(site: site)
            } else {
                SiteHomeView(sites: sites, onAddSite: presentNewSite)
            }
        }
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
            selection = .home
        }

        modelContext.delete(sitePendingDeletion)
        self.sitePendingDeletion = nil
    }
}

private struct AlertsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Alerts", systemImage: "bell")
        } description: {
            Text("Alert data has not been connected yet.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Site.self, CustomLocation.self], inMemory: true)
}
