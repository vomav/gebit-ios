import SwiftUI
import MapKit

struct PartAssignmentMapPreview: View {
    let partCoordinates: String?
    let boundaryCoordinates: String?
    
    var body: some View {
        let partCoords = parseCoordinateString(partCoordinates)
        let boundaryCoords = parseCoordinateString(boundaryCoordinates)
        let allCoords = (partCoords ?? []) + (boundaryCoords ?? [])
        
        if !allCoords.isEmpty {
            let region = calculateMapRegion(for: allCoords)
            
            Map(initialPosition: .region(region), interactionModes: []) {
                if let coords = partCoords, !coords.isEmpty {
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(.blue.opacity(0.25))
                        .stroke(.blue, lineWidth: 1.5)
                }
                
                if let coords = boundaryCoords, !coords.isEmpty {
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(.red.opacity(0.15))
                        .stroke(.red, lineWidth: 1.5)
                }
            }
            .mapStyle(.standard)
            .allowsHitTesting(false)
        }
    }
}
