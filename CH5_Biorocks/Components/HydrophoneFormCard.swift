import SwiftUI
import MapKit
import AVFoundation

struct HydrophoneFormCard: View {
    var initialLocation: CustomLocation?

    // Callbacks
    var onCancel: () -> Void
    var onSubmit: (String, Double, Double, String, String) -> Void

    // State
    @State private var name: String = ""
    @State private var latitudeStr: String = ""
    @State private var longitudeStr: String = ""
    @State private var microphones: [MicrophoneDevice] = []
    @State private var selectedMicrophoneID = ""
    @StateObject private var microphoneTester = MicrophoneInputTester()

    // Derived Coordinate for the Map
    private var currentCoordinate: CLLocationCoordinate2D? {
        if let lat = Double(latitudeStr), let lon = Double(longitudeStr) {
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
            Text(isEditMode ? "EDIT HYDROPHONE" : "ADD HYDROPHONE")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.primary)
                .padding(.bottom, 5)

            // Name Field
            CustomTextField(text: $name, placeholder: "Name (e.g. Dragon Structure)")

            // Latitude Field
            CustomTextField(text: $latitudeStr, placeholder: "Latitude (e.g. -8.128667)")

            // Longitude Field
            CustomTextField(text: $longitudeStr, placeholder: "Longitude (e.g. 114.660816)")

            microphoneInputSection

            // Map Preview
            ZStack {
                if let coord = currentCoordinate {
                    Map(bounds: MapCameraBounds(minimumDistance: 1000, maximumDistance: 5000)) {
                        Marker(name, coordinate: coord)
                            .tint(.red)
                    }
                    // Force the map to center on the coordinate whenever it changes
                    .id("\(coord.latitude)_\(coord.longitude)")
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
            HStack(spacing: 15) {
                Spacer()

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, height: 40)
                        .background(.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let lat = Double(latitudeStr),
                       let lon = Double(longitudeStr),
                       let microphone = selectedMicrophone,
                       isValid {
                        onSubmit(trimmedName, lat, lon, microphone.id, microphone.name)
                    }
                }) {
                    Text("Submit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 40)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                // Disable submit if inputs are invalid
                .disabled(!isValid)
                .opacity(isValid ? 1.0 : 0.5)
            }
        }
        .padding(30)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .frame(maxWidth: 500)
        .onAppear {
            if let loc = initialLocation {
                name = loc.name
                latitudeStr = String(loc.latitude)
                longitudeStr = String(loc.longitude)
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

// Reusable TextField for the form
struct CustomTextField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding()
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .font(.system(size: 16))
    }
}

#Preview {
    HydrophoneFormCard(
        initialLocation: nil,
        onCancel: {},
        onSubmit: { _, _, _, _, _ in }
    )
    .padding()
}
