//
//  ContentView.swift
//  CH5_Biorocks
//
//  Created by Gleenryan on 11/08/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .onboarding
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
                // Set the default, minimum, and maximum width for the sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            if let item = selectedItem {
                switch item {
                case .onboarding:
                    onBoardingView()
                case .microphone:
                    microphoneView()
                }
            } else {
                Text("Select an item from the sidebar")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
