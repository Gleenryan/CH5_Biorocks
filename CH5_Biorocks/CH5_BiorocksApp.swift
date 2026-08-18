//
//  CH5_BiorocksApp.swift
//  CH5_Biorocks
//
//  Created by Gleenryan on 11/08/26.
//

import SwiftUI
import SwiftData

@main
struct CH5_BiorocksApp: App {
    var body: some Scene {
        WindowGroup("Reef Monitor") {
            ContentView()
        }
        .defaultSize(width: 1_200, height: 800)
        .modelContainer(for: [Site.self, CustomLocation.self])
    }
}
