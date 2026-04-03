import Foundation
import MapKit

/// Parses a JSON coordinate string like `[[lng, lat], [lng, lat], ...]` into an array of coordinates.
func parseCoordinateString(_ coordinateString: String?) -> [CLLocationCoordinate2D]? {
    guard let coordinateString = coordinateString, !coordinateString.isEmpty else {
        return nil
    }
    
    guard let data = coordinateString.data(using: .utf8) else {
        return nil
    }
    
    do {
        let coordArrays = try JSONDecoder().decode([[Double]].self, from: data)
        var coordinates: [CLLocationCoordinate2D] = []
        
        for coordPair in coordArrays {
            guard coordPair.count == 2 else { continue }
            // GeoJSON format: [longitude, latitude]
            coordinates.append(CLLocationCoordinate2D(latitude: coordPair[1], longitude: coordPair[0]))
        }
        
        return coordinates.isEmpty ? nil : coordinates
    } catch {
        return nil
    }
}

/// Calculates a map region that encompasses all the given coordinates with padding.
func calculateMapRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
    guard !coordinates.isEmpty else {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
    
    var minLat = coordinates[0].latitude
    var maxLat = coordinates[0].latitude
    var minLon = coordinates[0].longitude
    var maxLon = coordinates[0].longitude
    
    for coordinate in coordinates {
        minLat = min(minLat, coordinate.latitude)
        maxLat = max(maxLat, coordinate.latitude)
        minLon = min(minLon, coordinate.longitude)
        maxLon = max(maxLon, coordinate.longitude)
    }
    
    let centerLat = (minLat + maxLat) / 2
    let centerLon = (minLon + maxLon) / 2
    let spanLat = (maxLat - minLat) * 1.5
    let spanLon = (maxLon - minLon) * 1.5
    
    return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
        span: MKCoordinateSpan(
            latitudeDelta: max(spanLat, 0.005),
            longitudeDelta: max(spanLon, 0.005)
        )
    )
}
