import SwiftUI

enum SidebarDestination: Hashable {
    case home
    case sites
#if DEBUG
    case simulator
#endif
    case alerts
    case alert(UUID)
    case siteAlerts(UUID)
    case site(UUID)
}

struct SidebarView: View {
    let sites: [Site]
    @Binding var selection: SidebarDestination?
    let onAddSite: () -> Void
    let onDeleteSite: (Site) -> Void

    @State private var isSitesExpanded = true

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Home", systemImage: "house")
                    .tag(SidebarDestination.home)

                Label("Alerts", systemImage: "bell")
                    .tag(SidebarDestination.alerts)
            }

            Section {
                DisclosureGroup(isExpanded: $isSitesExpanded) {
//                    Label("All Sites", systemImage: "list.bullet")
//                        .tag(SidebarDestination.sites)

                    if sites.isEmpty {
                        Text("No Sites yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(sites) { site in
                            Label {
                                Text(site.name)
                                    .lineLimit(1)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            .tag(SidebarDestination.site(site.id))
                            .contextMenu {
                                Button("Delete Site", role: .destructive) {
                                    onDeleteSite(site)
                                }
                            }
                        }
                    }

                    Button(action: onAddSite) {
                        Label("Add Site", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 4)
                } label: {
                    Label("Sites", systemImage: "folder")
                        .fontWeight(.medium)
                }
            }

#if DEBUG
            Section("Tools") {
                Label("Simulator", systemImage: "waveform.path.ecg")
                    .tag(SidebarDestination.simulator)
            }
#endif
        }
        .listStyle(.sidebar)
        .navigationTitle("Reef Monitor")
    }
}

#Preview {
    SidebarView(
        sites: [
            Site(
                name: "Pemuteran",
                startLatitude: -8.1287,
                startLongitude: 114.6608,
                endLatitude: -8.1322,
                endLongitude: 114.6715
            )
        ],
        selection: .constant(.home),
        onAddSite: {},
        onDeleteSite: { _ in }
    )
    .frame(width: 260, height: 600)
}
