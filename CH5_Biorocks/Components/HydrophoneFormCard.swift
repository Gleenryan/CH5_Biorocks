import SwiftUI
import MapKit
import AVFoundation

struct HydrophoneFormCard: View {
    var initialLocation: CustomLocation?
    var defaultCoordinate: CLLocationCoordinate2D
    var siteCoverageCenter: CLLocationCoordinate2D
    var siteCoverageRadiusMeters: CLLocationDistance

    // Callbacks
    var onCancel: () -> Void
    var onSubmit: (String, Double, Double, String, String) -> Void

    // State
    @State private var name: String = ""
    @State private var latitudeStr: String = ""
    @State private var longitudeStr: String = ""
    @State private var microphones: [MicrophoneDevice] = []
    @State private var selectedMicrophoneID = ""
    @State private var isPlacingOnMap = false
    @StateObject private var microphoneTester = MicrophoneInputTester()

    private let mapCoordinateSpace = "hydrophone-form-map"

    // Derived Coordinate for the Map
    private var currentCoordinate: CLLocationCoordinate2D? {
        if let lat = Double(latitudeStr),
           let lon = Double(longitudeStr),
           (-90...90).contains(lat),
           (-180...180).contains(lon) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }

    private var isEditMode: Bool {
        initialLocation != nil
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedMicrophone: MicrophoneDevice? {
        microphones.first { $0.id == selectedMicrophoneID }
    }

    private var isValid: Bool {
        guard let latitude = Double(latitudeStr), let longitude = Double(longitudeStr) else {
            return false
        }

        return !trimmedName.isEmpty
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
            && selectedMicrophone != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isEditMode ? "Edit Hydrophone" : "New Hydrophone")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(Color.coralystText)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.secondary.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .keyboardShortcut(.cancelAction)
            }
            
            Divider()
                .padding(.bottom, 8)

            HydrophoneTextField(title: "Hydrophone name", placeholder: "e.g. Dragon Structure", text: $name)

            HStack(spacing: 36) {
                HydrophoneTextField(title: "Latitude", placeholder: "-8.128667", text: $latitudeStr)
                HydrophoneTextField(title: "Longitude", placeholder: "114.660816", text: $longitudeStr)
            }

            microphoneInputSection

            // Map Preview
            ZStack {
                if let coord = currentCoordinate {
                    MapReader { proxy in
                        ZStack(alignment: .topLeading) {
                            Map(
                                bounds: MapCameraBounds(minimumDistance: 250, maximumDistance: 50_000),
                                interactionModes: isPlacingOnMap ? [] : .all
                            ) {
                                MapCircle(
                                    center: siteCoverageCenter,
                                    radius: max(siteCoverageRadiusMeters, 1)
                                )
                                .foregroundStyle(Color(hex: "17C3B2").opacity(0.14))
                                .stroke(Color(hex: "17C3B2"), lineWidth: 2)

                                Annotation("", coordinate: coord) {
                                    hydrophoneMapMarker
                                        .highPriorityGesture(
                                            TapGesture(count: 2)
                                                .onEnded { isPlacingOnMap = true }
                                        )
                                }
                            }

                            if isPlacingOnMap {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(placementGesture(using: proxy))

                                Label("Move the microphone, then release to confirm", systemImage: "cursorarrow.motionlines")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(.regularMaterial, in: Capsule())
                                    .padding(10)
                                    .allowsHitTesting(false)
                            } else {
                                Label("Double-click the microphone to move it", systemImage: "cursorarrow.click.2")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(.regularMaterial, in: Capsule())
                                    .padding(10)
                                    .allowsHitTesting(false)
                            }
                        }
                        .coordinateSpace(.named(mapCoordinateSpace))
                    }
                } else {
                    Rectangle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            Text("Enter valid coordinates to preview on map")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(height: 150)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            // Buttons
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(SiteSecondaryButtonStyle())

                Button("Save Hydrophone") {
                    if let lat = Double(latitudeStr),
                       let lon = Double(longitudeStr),
                       let microphone = selectedMicrophone,
                       isValid {
                        onSubmit(trimmedName, lat, lon, microphone.id, microphone.name)
                    }
                }
                .buttonStyle(SitePrimaryButtonStyle())
                .disabled(!isValid)
                .opacity(isValid ? 1.0 : 0.5)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .siteGlassCard(cornerRadius: 12)
        .frame(maxWidth: 500)
        .onAppear {
            if let loc = initialLocation {
                name = loc.name
                latitudeStr = String(loc.latitude)
                longitudeStr = String(loc.longitude)
            } else {
                latitudeStr = formattedCoordinate(defaultCoordinate.latitude)
                longitudeStr = formattedCoordinate(defaultCoordinate.longitude)
            }
            refreshMicrophones()
        }
        .onChange(of: selectedMicrophoneID) { _, _ in
            microphoneTester.stopTest()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in
            refreshMicrophones()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in
            refreshMicrophones()
        }
        .onDisappear {
            microphoneTester.stopTest()
        }
    }

    private var hydrophoneMapMarker: some View {
        VStack(spacing: 2) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: isPlacingOnMap ? 32 : 28, weight: .semibold))
                .foregroundStyle(.white, isPlacingOnMap ? Color.accentColor : .orange)
                .shadow(color: isPlacingOnMap ? Color.accentColor.opacity(0.7) : .black.opacity(0.25), radius: isPlacingOnMap ? 7 : 2, y: 1)

            Text(trimmedName.isEmpty ? "Hydrophone" : trimmedName)
                .font(.caption2.bold())
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: Capsule())
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isPlacingOnMap)
    }

    private func placementGesture(using proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(mapCoordinateSpace))
            .onChanged { value in
                guard let coordinate = proxy.convert(value.location, from: .named(mapCoordinateSpace)) else {
                    return
                }
                latitudeStr = formattedCoordinate(coordinate.latitude)
                longitudeStr = formattedCoordinate(coordinate.longitude)
            }
            .onEnded { _ in
                isPlacingOnMap = false
            }
    }

    private func formattedCoordinate(_ value: CLLocationDegrees) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(6))
                .grouping(.never)
        )
    }

    private var microphoneInputSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("INPUT MICROPHONE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: refreshMicrophones) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh microphones")
            }

            Picker("Input microphone", selection: $selectedMicrophoneID) {
                Text("Choose a microphone").tag("")

                if !selectedMicrophoneID.isEmpty, selectedMicrophone == nil {
                    Text("Unavailable: \(initialLocation?.microphoneDeviceName ?? "Saved microphone")")
                        .tag(selectedMicrophoneID)
                }

                ForEach(microphones) { microphone in
                    Text(microphone.name).tag(microphone.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(microphones.isEmpty)

            if let selectedMicrophone {
                HStack(spacing: 9) {
                    Circle()
                        .fill(microphoneTester.status.isWorking ? .green : .red)
                        .frame(width: 9, height: 9)
                        .accessibilityLabel(microphoneTester.status.isWorking ? "Microphone working" : "Microphone not receiving audio")

                    Text(microphoneTester.status.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(microphoneTester.isTesting ? "Stop Test" : "Test Microphone") {
                        if microphoneTester.isTesting {
                            microphoneTester.stopTest()
                        } else {
                            microphoneTester.startTest(deviceID: selectedMicrophone.id)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else if microphones.isEmpty {
                Text("No microphone inputs are currently available.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Choose a microphone to test it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func refreshMicrophones() {
        let rememberedDeviceID = initialLocation?.microphoneDeviceID
        let currentDeviceID = selectedMicrophoneID

        microphones = MicrophoneDevice.availableDevices()

        if let rememberedDeviceID, currentDeviceID.isEmpty {
            selectedMicrophoneID = rememberedDeviceID
        } else if !currentDeviceID.isEmpty,
                  microphones.contains(where: { $0.id == currentDeviceID }) {
            selectedMicrophoneID = currentDeviceID
        } else if currentDeviceID.isEmpty {
            selectedMicrophoneID = ""
        } else {
            selectedMicrophoneID = ""
        }
    }
}

private struct HydrophoneTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
        }
    }
}

#Preview {
    HydrophoneFormCard(
        initialLocation: nil,
        defaultCoordinate: CLLocationCoordinate2D(latitude: -8.128667, longitude: 114.660816),
        siteCoverageCenter: CLLocationCoordinate2D(latitude: -8.128667, longitude: 114.660816),
        siteCoverageRadiusMeters: 600,
        onCancel: {},
        onSubmit: { _, _, _, _, _ in }
    )
    .padding()
}
