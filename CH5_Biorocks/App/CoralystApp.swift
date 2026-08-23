import SwiftUI
import SwiftData

@main
struct CoralystApp: App {
    @StateObject private var detectionStore = DetectionStore()
    @StateObject private var hydrophoneHub = HydrophoneHub()

    var body: some Scene {
        WindowGroup("Reef Monitor") {
            AppShellView()
                .environmentObject(detectionStore)
                .environmentObject(hydrophoneHub)
        }
        .defaultSize(width: 1_200, height: 800)
        .modelContainer(for: [
            Site.self,
            CustomLocation.self,
            BlastDetectionEvent.self,
            HealthSnapshotRecord.self
        ])
    }
}
