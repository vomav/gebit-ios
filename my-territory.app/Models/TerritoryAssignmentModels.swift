import Foundation

struct TerritoryAssignment: Codable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let link: String?
    let startedDate: String?
    let finishedDate: String?
    let availableTerritoryCount: Int?
    let inProgressTerritoryCount: Int?
    let totalTerritoryCount: Int?
    let toPartAssignments: [PartAssignment]?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "name"
        case type = "type"
        case link = "link"
        case startedDate = "startedDate"
        case finishedDate = "finishedDate"
        case availableTerritoryCount = "availableTerritoryCount"
        case inProgressTerritoryCount = "inProgressTerritoryCount"
        case totalTerritoryCount = "totalTerritoryCount"
        case toPartAssignments = "toPartAssignments"
    }
}

struct PartAssignment: Codable, Identifiable {
    let id: String
    let name: String?
    let coordinates: String?
    let isBoundaries: Bool?
    let isDone: Bool?
    let inWorkBy: [InWorkBy]?
    let toBoundaryPart: BoundaryPart?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "name"
        case coordinates = "coordinates"
        case isBoundaries = "isBoundaries"
        case isDone = "isDone"
        case inWorkBy = "inWorkBy"
        case toBoundaryPart = "toBoundaryPart"
    }
    
    var firstWorker: InWorkBy? {
        inWorkBy?.first
    }
}

struct InWorkBy: Codable {
    let name: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case email = "email"
    }
}
