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
        colorScheme == .dark ? .white : Color(hex: "0F172A")
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
        VStack(spacing: 0) {
            // Modal Header
            modalHeader
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 18)

            Divider()

            // Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    siteDetailsSection
                    Divider().opacity(0.6)
                    hydrophonesSection
                }
                .padding(28)
            }
            .scrollIndicators(.automatic)

            Divider()

            // Bottom Actions
            actionsToolbar
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
        }
        .frame(width: 720)
        .frame(maxHeight: 740)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 30, y: 12)
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
            Text("This hydrophone will be permanently removed from this site.")
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
            Text("This will permanently delete this site and all of its configured hydrophones.")
        }
    }

    // MARK: - Modal Header
    private var modalHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.coralystPrimary.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Site Settings")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryText)

                Text("Configure location parameters, geographic bounds & hydrophones")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Close settings")
        }
    }

    // MARK: - Site Details & Coordinates
    private var siteDetailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)
                Text("General & Coordinates")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(primaryText)
            }

            // Site Name Field
            ModernSettingsField(
                title: "Site Name",
                icon: "tag.fill",
                placeholder: "e.g. Pemuteran Reef 1",
                text: $name,
                primaryText: primaryText
            )

            // Coordinate Bounding Box Group
            VStack(alignment: .leading, spacing: 14) {
                // Start Coordinates
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "10B981"))
                            .frame(width: 7, height: 7)
                        Text("Start Boundary")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(primaryText)
                    }

                    HStack(spacing: 16) {
                        ModernSettingsField(
                            title: "Latitude",
                            icon: "location.north.line.fill",
                            placeholder: "-8.128700",
                            text: $startLatitude,
                            primaryText: primaryText
                        )
                        ModernSettingsField(
                            title: "Longitude",
                            icon: "location.north.line.fill",
                            placeholder: "114.660800",
                            text: $startLongitude,
                            primaryText: primaryText
                        )
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
                )

                // Finish Coordinates
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 7, height: 7)
                        Text("Finish Boundary")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(primaryText)
                    }

                    HStack(spacing: 16) {
                        ModernSettingsField(
                            title: "Latitude",
                            icon: "location.north.line.fill",
                            placeholder: "-8.132200",
                            text: $endLatitude,
                            primaryText: primaryText
                        )
                        ModernSettingsField(
                            title: "Longitude",
                            icon: "location.north.line.fill",
                            placeholder: "114.671500",
                            text: $endLongitude,
                            primaryText: primaryText
                        )
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
                )
            }

            if !isValid {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Please enter a valid name and coordinate bounds (Lat: −90 to 90, Lon: −180 to 180).")
                        .font(.system(size: 11.5))
                }
                .foregroundStyle(Color(hex: "EF4444"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "EF4444").opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Hydrophones Section
    private var hydrophonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.badge.waveform")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.coralystPrimary)

                    Text("Hydrophone Fleet")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(primaryText)

                    Text("\(sortedHydrophones.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.coralystPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.coralystPrimary.opacity(0.12), in: Capsule())
                }

                Spacer()

                Button(action: onAddHydrophone) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("New Hydrophone")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.coralystPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if sortedHydrophones.isEmpty {
                ContentUnavailableView {
                    Label("No Hydrophones Registered", systemImage: "mic.slash")
                        .font(.system(size: 13, weight: .semibold))
                } description: {
                    Text("Click 'New Hydrophone' to add a hydrophone to this site.")
                        .font(.system(size: 11.5))
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedHydrophones) { hydrophone in
                        hydrophoneRow(hydrophone)
                    }
                }
            }
        }
    }

    private func hydrophoneRow(_ hydrophone: CustomLocation) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.coralystPrimary.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.coralystPrimary)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(hydrophone.name)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(primaryText)

                Text(coordinateText(hydrophone.latitude, hydrophone.longitude))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    onEditHydrophone(hydrophone)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.coralystPrimary)
                        .frame(width: 30, height: 30)
                        .background(Color.coralystPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Edit \(hydrophone.name)")

                Button(role: .destructive) {
                    hydrophonePendingDeletion = hydrophone
                    isConfirmingHydrophoneDeletion = true
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "EF4444"))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "EF4444").opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Delete \(hydrophone.name)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
        )
    }

    // MARK: - Actions Toolbar
    private var actionsToolbar: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                isConfirmingSiteDeletion = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Delete Site")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "EF4444"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "EF4444").opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Button(action: submit) {
                Text("Save Changes")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(isValid ? Color.coralystPrimary : Color.gray.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
            .keyboardShortcut(.defaultAction)
        }
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
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), (-90 ... 90).contains(value) else { return nil }
        return value
    }

    private func validLongitude(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), (-180 ... 180).contains(value) else { return nil }
        return value
    }

    private func coordinateText(_ latitude: Double, _ longitude: Double) -> String {
        "\(Self.coordinateText(latitude)), \(Self.coordinateText(longitude))"
    }

    private static func coordinateText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(6)))
    }
}

// MARK: - Modern Settings Text Field
private struct ModernSettingsField: View {
    let title: String
    var icon: String? = nil
    var placeholder: String = ""
    @Binding var text: String
    let primaryText: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.coralystPrimary.opacity(0.7))
                }

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .medium, design: title.contains("Latitude") || title.contains("Longitude") ? .monospaced : .default))
                    .foregroundStyle(primaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let previewSite = Site(
        name: "Pemuteran 1",
        startLatitude: -8.128667,
        startLongitude: 114.660816,
        endLatitude: -8.1322,
        endLongitude: 114.6715
    )

    let previewHydrophone = CustomLocation(
        name: "North Reef Mic",
        latitude: -8.129,
        longitude: 114.662
    )

    previewSite.hydrophones.append(previewHydrophone)
    previewHydrophone.site = previewSite

    return SiteSettingsOverlay(
        site: previewSite,
        onCancel: {},
        onFinish: { _, _, _, _, _ in },
        onAddHydrophone: {},
        onEditHydrophone: { _ in },
        onDeleteHydrophone: { _ in },
        onDeleteSite: { _ in }
    )
    .frame(width: 900, height: 1200)
    .padding()
}
