import SwiftUI
import MapKit

struct HydrophoneFormCard: View {
    var initialLocation: CustomLocation?

    // Callbacks
    var onCancel: () -> Void
    var onSubmit: (String, Double, Double) -> Void

    // State
    @State private var name: String = ""
    @State private var latitudeStr: String = ""
    @State private var longitudeStr: String = ""

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

    private var isValid: Bool {
        guard let latitude = Double(latitudeStr), let longitude = Double(longitudeStr) else {
            return false
        }

        return !trimmedName.isEmpty
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isEditMode ? "EDIT HYDROPHONE" : "ADD HYDROPHONE")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.black)
                .padding(.bottom, 5)

            // Name Field
            CustomTextField(text: $name, placeholder: "Name (e.g. Dragon Structure)")

            // Latitude Field
            CustomTextField(text: $latitudeStr, placeholder: "Latitude (e.g. -8.128667)")

            // Longitude Field
            CustomTextField(text: $longitudeStr, placeholder: "Longitude (e.g. 114.660816)")

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
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Text("Enter valid coordinates to preview on map")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(height: 200)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )

            // Buttons
            HStack(spacing: 15) {
                Spacer()

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 100, height: 40)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let lat = Double(latitudeStr), let lon = Double(longitudeStr), isValid {
                        onSubmit(trimmedName, lat, lon)
                    }
                }) {
                    Text("Submit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 40)
                        .background(Color(hex: "17C3B2")) // Teal color
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                // Disable submit if inputs are invalid
                .disabled(!isValid)
                .opacity(isValid ? 1.0 : 0.5)
            }
        }
        .padding(30)
        .background(Color(hex: "EEF1F6"))
        .cornerRadius(12)
        .frame(maxWidth: 500)
        .onAppear {
            if let loc = initialLocation {
                name = loc.name
                latitudeStr = String(loc.latitude)
                longitudeStr = String(loc.longitude)
            }
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
            .background(Color.black.opacity(0.03))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
            .font(.system(size: 16))
    }
}

#Preview {
    HydrophoneFormCard(
        initialLocation: nil,
        onCancel: {},
        onSubmit: { _, _, _ in }
    )
    .padding()
}
