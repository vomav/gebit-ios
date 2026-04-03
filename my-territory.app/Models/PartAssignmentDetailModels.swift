import Foundation

struct PartAssignmentDetail: Codable, Identifiable {
    let id: String
    let coordinates: String?
    let count: Int?
    let isDone: Bool?
    let name: String
    let workedPartImageUrl: String?
    let inWorkBy: [WorkerDetail]?
    let toAllowedUsers: [AllowedUser]?
    let toBoundaryPart: BoundaryPart?
    let toParent: ParentAssignment?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case coordinates = "coordinates"
        case count = "count"
        case isDone = "isDone"
        case name = "name"
        case workedPartImageUrl = "workedPartImageUrl"
        case inWorkBy = "inWorkBy"
        case toAllowedUsers = "toAllowedUsers"
        case toBoundaryPart = "toBoundaryPart"
        case toParent = "toParent"
    }
}

struct WorkerDetail: Codable, Identifiable {
    let id: String
    let freestyleName: String?
    let surname: String?
    let username: String?
    
    var displayName: String {
        if let freestyle = freestyleName, !freestyle.isEmpty {
            return freestyle
        }
        if let surname = surname, !surname.isEmpty {
            return surname
        }
        return username ?? String(localized: "Unknown")
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case freestyleName = "freestyleName"
        case surname = "surname"
        case username = "username"
    }
}

struct AllowedUser: Codable, Identifiable {
    let id: String
    let name: String?
    let surname: String?
    let tenantID: String?
    
    var displayName: String {
        let parts = [name, surname].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? String(localized: "Unknown User") : parts.joined(separator: " ")
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "user_ID"
        case name = "name"
        case surname = "surname"
        case tenantID = "tenant_ID"
    }
}

struct BoundaryPart: Codable, Identifiable {
    let id: String
    let coordinates: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case coordinates = "coordinates"
    }
}

struct ParentAssignment: Codable, Identifiable {
    let id: String
    let toTerritory: TerritoryInfo?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case toTerritory = "toTerritory"
    }
}

struct TerritoryInfo: Codable, Identifiable {
    let id: String
    let link: String?
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case link = "link"
        case name = "name"
    }
}
