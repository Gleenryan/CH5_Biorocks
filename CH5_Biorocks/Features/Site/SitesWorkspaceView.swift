import SwiftUI
import SwiftData

struct SitesWorkspaceView: View {
    let sites: [Site]
    let selectedSite: Site
    let onSelectSite: (Site) -> Void
    let onAddSite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            GeometryReader { proxy in
                if proxy.size.width >= 820 {
                    HSplitView {
                        SiteCatalogPanel(
                            sites: sites,
                            selectedSiteID: selectedSite.id,
                            onSelectSite: onSelectSite
                        )
                        .frame(minWidth: 250, idealWidth: 290, maxWidth: 340)

                        SiteDetailView(site: selectedSite)
                            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 14) {
                        Picker("Site", selection: selectedSiteBinding) {
                            ForEach(sites) { site in
                                Text(site.name).tag(site.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        SiteDetailView(site: selectedSite)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sites")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Monitor and manage reef Sites and their hydrophones.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onAddSite) {
                Label("Add Site", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var selectedSiteBinding: Binding<UUID> {
        Binding(
            get: { selectedSite.id },
            set: { newID in
                guard let site = sites.first(where: { $0.id == newID }) else { return }
                onSelectSite(site)
            }
        )
    }
}

private struct SiteCatalogPanel: View {
    let sites: [Site]
    let selectedSiteID: UUID
    let onSelectSite: (Site) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("All Sites")
                    .font(.headline)

                Text("\(sites.count)")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())

                Spacer()
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sites) { site in
                        SiteCatalogRow(
                            site: site,
                            isSelected: site.id == selectedSiteID,
                            action: { onSelectSite(site) }
                        )
                    }
                }
                .padding(2)
            }
            .scrollIndicators(.hidden)

            Text("\(sites.count) Site\(sites.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .siteGlassCard(cornerRadius: 18)
    }
}

private struct SiteCatalogRow: View {
    let site: Site
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SiteImagePlaceholder(showsLabel: false)
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Label(
                        "\(site.hydrophones.count) hydrophone\(site.hydrophones.count == 1 ? "" : "s")",
                        systemImage: "mic"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(site.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .siteGlassCard(cornerRadius: 14, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: isSelected ? 2 : 0
                )
        }
    }
}

#Preview {
    let site = Site(
        name: "Nusa Penida (Demo)",
        startLatitude: -8.7270,
        startLongitude: 115.5440,
        endLatitude: -8.7205,
        endLongitude: 115.5530
    )

    SitesWorkspaceView(
        sites: [site],
        selectedSite: site,
        onSelectSite: { _ in },
        onAddSite: {}
    )
    .modelContainer(for: [Site.self, CustomLocation.self], inMemory: true)
    .frame(width: 1_200, height: 800)
}
