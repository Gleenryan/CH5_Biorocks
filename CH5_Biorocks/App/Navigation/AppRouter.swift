import Foundation
import Combine

/// Owns app-level navigation state and preserves the screen a user came from
/// when opening an alert detail screen.
@MainActor
final class AppRouter: ObservableObject {
    @Published var selection: SidebarDestination? = .home

    private var selectionBeforeAlert: SidebarDestination?

    func noteSelectionChange(to newSelection: SidebarDestination?) {
        guard let newSelection, case .alert = newSelection else {
            selectionBeforeAlert = nil
            return
        }
    }

    func showAlert(_ alert: BlastDetectionEvent) {
        if let selection, case .alert = selection {
            // Preserve the original source while changing between alert details.
        } else {
            selectionBeforeAlert = selection
        }
        selection = .alert(alert.id)
    }

    func dismissAlertDetail() {
        selection = selectionBeforeAlert ?? .home
        selectionBeforeAlert = nil
    }
}
