import SwiftUI
import MapKit

struct DistrictMapView: View {
    let category: Category
    @State private var position: MapCameraPosition
    
    init(category: Category) {
        self.category = category
        if let region = category.region {
            _position = State(initialValue: .region(region))
        } else if let coordinate = category.coordinate {
            _position = State(initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            ))
        } else {
            _position = State(initialValue: .automatic)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title)
                    .foregroundStyle(.tint)
                
                VStack(alignment: .leading) {
                    Text(category.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("District Territory Map")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            // Map
            Map(position: $position) {
                if let coordinate = category.coordinate {
                    Marker(category.name, systemImage: "building.2.fill", coordinate: coordinate)
                        .tint(.blue)
                }
                
                // Show polygon if available
                if let polygonCoords = category.polygonCoordinates, !polygonCoords.isEmpty {
                    MapPolygon(coordinates: polygonCoords)
                        .foregroundStyle(.blue.opacity(0.3))
                        .stroke(.blue, lineWidth: 2)
                } else if let coordinate = category.coordinate {
                    // Fallback to circle if no polygon
                    MapCircle(center: coordinate, radius: 1000)
                        .foregroundStyle(.blue.opacity(0.2))
                        .stroke(.blue, lineWidth: 2)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            
            // Info Panel
            VStack(alignment: .leading, spacing: 12) {
                Text("Territory Information")
                    .font(.headline)
                
                if let coordinate = category.coordinate {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.secondary)
                        Text("Latitude: \(coordinate.latitude, specifier: "%.4f")")
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.secondary)
                        Text("Longitude: \(coordinate.longitude, specifier: "%.4f")")
                    }
                    .font(.subheadline)
                }
                
                Divider()
                
                Text("Use the map controls to explore the territory. You can zoom, rotate, and switch between different map views.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .navigationTitle(category.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
