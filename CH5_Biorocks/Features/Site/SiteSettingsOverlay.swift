import SwiftUI

struct SiteSettingsOverlay: View {
    let site: Site
    let onCancel: () -> Void
    let onFinish: (String, Double, Double, Double, Double) -> Void
    let onAddHydrophone: () -> Void
    let onEditHydrophone: (CustomLocation) -> Void
    let onDeleteHydrophone: (CustomLocation) -> Void
    let onDeleteSite: (Site) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var name: String
    @State private var startLatitude: String
    @State private var startLongitude: String
    @State private var endLatitude: String
    @State private var endLongitude: String
    @State private var hydrophonePendingDeletion: CustomLocation?
    @State private var isConfirmingHydrophoneDeletion = false
    @State private var isConfirmingSiteDeletion = false

    init(
        site: Site,
        onCancel: @escaping () -> Void,
        onFinish: @escaping (String, Double, Double, Double, Double) -> Void,
        onAddHydrophone: @escaping () -> Void,
        onEditHydrophone: @escaping (CustomLocation) -> Void,
        onDeleteHydrophone: @escaping (CustomLocation) -> Void,
        onDeleteSite: @escaping (Site) -> Void
    ) {
        self.site = site
        self.onCancel = onCancel
        self.onFinish = onFinish
        self.onAddHydrophone = onAddHydrophone
        self.onEditHydrophone = onEditHydrophone
        self.onDeleteHydrophone = onDeleteHydrophone
        self.onDeleteSite = onDeleteSite
        _name = State(initialValue: site.name)
        _startLatitude = State(initialValue: Self.coordinateText(site.startLatitude))
        _startLongitude = State(initialValue: Self.coordinateText(site.startLongitude))
        _endLatitude = State(initialValue: Self.coordinateText(site.endLatitude))
        _endLongitude = State(initialValue: Self.coordinateText(site.endLongitude))
    }

    private var primaryText: Color {
        colorScheme == .dark ? .primary : .coralystText
    }

    private var sortedHydrophones: [CustomLocation] {
        site.hydrophones.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedStartLatitude: Double? { validLatitude(startLatitude) }
    private var parsedStartLongitude: Double? { validLongitude(startLongitude) }
    private var parsedEndLatitude: Double? { validLatitude(endLatitude) }
    private var parsedEndLongitude: Double? { validLongitude(endLongitude) }

    private var isValid: Bool {
        !trimmedName.isEmpty
            && parsedStartLatitude != nil
            && parsedStartLongitude != nil
            && parsedEndLatitude != nil
            && parsedEndLongitude != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Site Settings")
                    .font(.system(size: 37, weight: .bold))
                    .foregroundStyle(primaryText)

                siteFields

                Divider()

                hydrophoneSettings

                actions
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .frame(width: 790)
        .frame(maxHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .confirmationDialog(
            "Delete \(hydrophonePendingDeletion?.name ?? "Hydrophone")?",
            isPresented: $isConfirmingHydrophoneDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Hydrophone", role: .destructive) {
                guard let hydrophonePendingDeletion else { return }
                onDeleteHydrophone(hydrophonePendingDeletion)
                self.hydrophonePendingDeletion = nil
            }
        } message: {
            Text("This hydrophone will be permanently removed from this Site.")
        }
        .confirmationDialog(
            "Delete \(site.name)?",
            isPresented: $isConfirmingSiteDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Site", role: .destructive) {
                onDeleteSite(site)
            }
        } message: {
            Text("This removes the Site and all of its hydrophones permanently.")
        }
    }

    private var siteFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            SiteSettingsTextField(title: "Site Name", text: $name)

            HStack(spacing: 24) {
                SiteSettingsTextField(title: "Start Latitude", text: $startLatitude)
                SiteSettingsTextField(title: "End Latitude", text: $endLatitude)
            }

            HStack(spacing: 24) {
                SiteSettingsTextField(title: "Start Longitude", text: $startLongitude)
                SiteSettingsTextField(title: "End Longitude", text: $endLongitude)
            }

            if !isValid {
                Text("Enter a name, latitude from −90 to 90, and longitude from −180 to 180.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var hydrophoneSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hydrophone Settings")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(primaryText)

                Spacer()

                Button(action: onAddHydrophone) {
                    Label("New Hydrophone", systemImage: "mic.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.coralystPrimary)
            }

            if sortedHydrophones.isEmpty {
                ContentUnavailableView {
                    Label("No Hydrophones", systemImage: "mic.slash")
                } description: {
                    Text("Add a hydrophone to this Site.")
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(sortedHydrophones) { hydrophone in
                    hydrophoneRow(hydrophone)
                    if hydrophone.id != sortedHydrophones.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func hydrophoneRow(_ hydrophone: CustomLocation) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hydrophone.name)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(primaryText)

                Text(coordinateText(hydrophone.latitude, hydrophone.longitude))
                    .font(.callout)
                    .foregroundStyle(primaryText.opacity(0.9))
            }

            Spacer(minLength: 16)

            Button {
                onEditHydrophone(hydrophone)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.coralystPrimary)
            .accessibilityLabel("Edit \(hydrophone.name)")

            Button(role: .destructive) {
                hydrophonePendingDeletion = hydrophone
                isConfirmingHydrophoneDeletion = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel("Delete \(hydrophone.name)")
        }
        .padding(.vertical, 7)
    }

    private var actions: some View {
        HStack(spacing: 14) {
            Spacer()

            Button("Finish", action: submit)
                .buttonStyle(.borderedProminent)
                .tint(Color.coralystPrimary)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)

            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

            Button("Delete Site", role: .destructive) {
                isConfirmingSiteDeletion = true
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .controlSize(.large)
        .padding(.top, 8)
    }

    private func submit() {
        guard
            let startLatitude = parsedStartLatitude,
            let startLongitude = parsedStartLongitude,
            let endLatitude = parsedEndLatitude,
            let endLongitude = parsedEndLongitude,
            isValid
        else {
            return
        }

        onFinish(trimmedName, startLatitude, startLongitude, endLatitude, endLongitude)
    }

    private func validLatitude(_ text: String) -> Double? {
        guard let value = Double(text), (-90 ... 90).contains(value) else { return nil }
        return value
    }

    private func validLongitude(_ text: String) -> Double? {
        guard let value = Double(text), (-180 ... 180).contains(value) else { return nil }
        return value
    }

    private func coordinateText(_ latitude: Double, _ longitude: Double) -> String {
        "\(Self.coordinateText(latitude)), \(Self.coordinateText(longitude))"
    }

    private static func coordinateText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(6)))
    }
}

private struct SiteSettingsTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.coralystText)

            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SiteSettingsOverlay(
        site: Site(
            name: "Pemuteran 1",
            startLatitude: -8.128667,
            startLongitude: 114.660816,
            endLatitude: -8.1322,
            endLongitude: 114.6715
        ),
        onCancel: {},
        onFinish: { _, _, _, _, _ in },
        onAddHydrophone: {},
        onEditHydrophone: { _ in },
        onDeleteHydrophone: { _ in },
        onDeleteSite: { _ in }
    )
    .frame(width: 900, height: 900)
    .padding()
}
