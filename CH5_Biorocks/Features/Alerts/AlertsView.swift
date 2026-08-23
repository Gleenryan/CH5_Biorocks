import SwiftData
import SwiftUI

enum AlertListScope {
    case all
    case site(name: String)

    var title: String {
        switch self {
        case .all:
            "All Alerts"
        case .site(let name):
            "\(name) Alerts"
        }
    }
}

private enum AlertFilter: CaseIterable, Identifiable {
    case recent
    case high
    case medium
    case low

    var id: Self { self }

    var tabTitle: String {
        switch self {
        case .recent: "Recents"
        case .high: "High Level"
        case .medium: "Medium Level"
        case .low: "Low Level"
        }
    }

    var sectionTitle: String {
        switch self {
        case .recent: "Recent Alerts"
        case .high: "High Level Alerts"
        case .medium: "Medium Level Alerts"
        case .low: "Low Level Alerts"
        }
    }

    func includes(_ event: BlastDetectionEvent) -> Bool {
        switch self {
        case .recent:
            true
        case .high:
            event.severity.localizedCaseInsensitiveCompare("high") == .orderedSame
        case .medium:
            event.severity.localizedCaseInsensitiveCompare("medium") == .orderedSame
        case .low:
            event.severity.localizedCaseInsensitiveCompare("low") == .orderedSame
        }
    }
}

struct AlertsView: View {
    let scope: AlertListScope
    let onSelectAlert: (BlastDetectionEvent) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \BlastDetectionEvent.onsetTime, order: .reverse)
    private var events: [BlastDetectionEvent]
    @State private var selectedFilter: AlertFilter = .recent

    init(
        scope: AlertListScope = .all,
        onSelectAlert: @escaping (BlastDetectionEvent) -> Void = { _ in }
    ) {
        self.scope = scope
        self.onSelectAlert = onSelectAlert
    }

    private var primaryText: Color {
        colorScheme == .dark ? .primary : .coralystText
    }

    private var scopedEvents: [BlastDetectionEvent] {
        switch scope {
        case .all:
            events
        case .site(let name):
            events.filter {
                $0.siteName.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
        }
    }

    private var filteredEvents: [BlastDetectionEvent] {
        scopedEvents.filter(selectedFilter.includes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(scope.title)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(primaryText)

                filterTabs

                Text(selectedFilter.sectionTitle)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(primaryText)

                if filteredEvents.isEmpty {
                    emptyState
                } else {
                    alertGrid
                }
            }
            .frame(maxWidth: 1_440, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 30)
        }
        .scrollIndicators(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var filterTabs: some View {
        HStack(alignment: .bottom, spacing: 24) {
            ForEach(AlertFilter.allCases) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(filter.tabTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                selectedFilter == filter
                                    ? primaryText
                                    : primaryText.opacity(0.68)
                            )

                        Rectangle()
                            .fill(selectedFilter == filter ? Color.coralystPrimary : .clear)
                            .frame(width: 52, height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(filter.tabTitle)
                .accessibilityValue(selectedFilter == filter ? "Selected" : "")
            }
        }
    }

    private var alertGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 270, maximum: 300), spacing: 38)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(filteredEvents) { event in
                Button {
                    onSelectAlert(event)
                } label: {
                    HomeAlertCard(
                        alert: HomeAlert(event: event),
                        primaryText: primaryText
                    )
                    .frame(maxWidth: 300, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Open alert details")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No \(selectedFilter.sectionTitle.lowercased())", systemImage: "bell.slash")
        } description: {
            Text(emptyMessage)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var emptyMessage: String {
        switch scope {
        case .all:
            "New detections will appear here when they are promoted to alerts."
        case .site(let name):
            "No matching alerts have been recorded for \(name)."
        }
    }
}

#Preview {
    AlertsView()
        .modelContainer(for: [Site.self, CustomLocation.self, BlastDetectionEvent.self], inMemory: true)
        .frame(width: 1_100, height: 720)
}
