//
//  ContentView.swift
//  CH5_Biorocks
//
//  Created by Gleenryan on 11/08/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedItem: SidebarItem?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        _selectedItem = State(initialValue: hasCompletedOnboarding ? .sites : .onboarding)
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedItem)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("")
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedItem ?? .sites {
        case .onboarding:
            onBoardingView {
                withAnimation(.easeInOut(duration: 0.35)) {
                    hasCompletedOnboarding = true
                    selectedItem = .sites
                }
            }

        case .sites:
            SiteHomeView()

        case .microphone:
            microphoneView()
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [Site.self, CustomLocation.self], inMemory: true)
}
