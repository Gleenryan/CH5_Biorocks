import SwiftUI
import SwiftData
import MapKit

struct microphoneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var locations: [CustomLocation]
    
    // Add new location state
    @State private var newName: String = ""
    @State private var newLat: String = ""
    @State private var newLong: String = ""
    
    // Edit state
    @State private var editingLocation: CustomLocation?
    
    var body: some View {
        NavigationSplitView {
            VStack {
                Form {
                    Section(header: Text(editingLocation == nil ? "Add Location" : "Edit Location")) {
                        TextField("Name", text: $newName)
                        TextField("Latitude", text: $newLat)
                        TextField("Longitude", text: $newLong)
                        
                        HStack {
                            if editingLocation != nil {
                                Button("Cancel") {
                                    clearForm()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button(editingLocation == nil ? "Add" : "Save") {
                                saveLocation()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newName.isEmpty || newLat.isEmpty || newLong.isEmpty)
                        }
                    }
                }
                .padding()
                
                List {
                    ForEach(locations) { location in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(location.name).font(.headline)
                                Text("\(location.latitude), \(location.longitude)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                startEditing(location)
                            }
                            .buttonStyle(.borderless)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteLocation(location)
                            }
                        }
                    }
                    .onDelete(perform: deleteLocations)
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            DynamicMapView(locations: locations)
        }
    }
    
    private func saveLocation() {
        guard let lat = Double(newLat), let long = Double(newLong) else { return }
        
        if let editingLocation = editingLocation {
            // Update existing
            editingLocation.name = newName
            editingLocation.latitude = lat
            editingLocation.longitude = long
        } else {
            // Add new
            let newLocation = CustomLocation(name: newName, latitude: lat, longitude: long)
            modelContext.insert(newLocation)
        }
        
        clearForm()
    }
    
    private func startEditing(_ location: CustomLocation) {
        editingLocation = location
        newName = location.name
        newLat = String(location.latitude)
        newLong = String(location.longitude)
    }
    
    private func deleteLocations(offsets: IndexSet) {
        for index in offsets {
            deleteLocation(locations[index])
        }
    }
    
    private func deleteLocation(_ location: CustomLocation) {
        if editingLocation?.id == location.id {
            clearForm()
        }
        modelContext.delete(location)
    }
    
    private func clearForm() {
        editingLocation = nil
        newName = ""
        newLat = ""
        newLong = ""
    }
}

#Preview {
    microphoneView()
        .modelContainer(for: CustomLocation.self, inMemory: true)
}
