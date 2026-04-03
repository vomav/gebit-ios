import Foundation
import MapKit

struct Category: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    var children: [Category]?
    var isDistrict: Bool = false
    var coordinate: CLLocationCoordinate2D?
    var region: MKCoordinateRegion?
    var polygonCoordinates: [CLLocationCoordinate2D]?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

enum SampleData {
    static let categories = [
        Category(name: "Territories", icon: "map", children: [
            Category(name: "North Region", icon: "location.north", children: [
                Category(
                    name: "District A",
                    icon: "building.2",
                    isDistrict: true,
                    coordinate: CLLocationCoordinate2D(latitude: 49.4766014, longitude: 8.4778835),
                    region: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 49.4770, longitude: 8.4807),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ),
                    polygonCoordinates: [
                        CLLocationCoordinate2D(latitude: 49.4766014, longitude: 8.4778835),
                        CLLocationCoordinate2D(latitude: 49.4765316, longitude: 8.4777333),
                        CLLocationCoordinate2D(latitude: 49.4753256, longitude: 8.4794928),
                        CLLocationCoordinate2D(latitude: 49.4774518, longitude: 8.4837629),
                        CLLocationCoordinate2D(latitude: 49.4787205, longitude: 8.4821965),
                        CLLocationCoordinate2D(latitude: 49.4766014, longitude: 8.4778835)
                    ]
                ),
                Category(
                    name: "District B",
                    icon: "building.2",
                    isDistrict: true,
                    coordinate: CLLocationCoordinate2D(latitude: 40.7282, longitude: -74.0776),
                    region: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 40.7282, longitude: -74.0776),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            ]),
            Category(name: "South Region", icon: "location.south", children: [
                Category(
                    name: "District C",
                    icon: "building.2",
                    isDistrict: true,
                    coordinate: CLLocationCoordinate2D(latitude: 40.6501, longitude: -73.9496),
                    region: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 40.6501, longitude: -73.9496),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                ),
                Category(
                    name: "District D",
                    icon: "building.2",
                    isDistrict: true,
                    coordinate: CLLocationCoordinate2D(latitude: 40.5795, longitude: -74.1502),
                    region: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 40.5795, longitude: -74.1502),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            ])
        ]),
        Category(name: "Reports", icon: "chart.bar", children: [
            Category(name: "Monthly", icon: "calendar"),
            Category(name: "Quarterly", icon: "calendar"),
            Category(name: "Annual", icon: "calendar")
        ]),
        Category(name: "Settings", icon: "gear", children: [
            Category(name: "General", icon: "slider.horizontal.3"),
            Category(name: "Privacy", icon: "lock.shield"),
            Category(name: "Notifications", icon: "bell")
        ])
    ]
}
