import Foundation

struct Territory: Codable, Identifiable {
    let id: String
    let name: String?
    let isReady: Bool?
    let assignedToName: String?
    let assignedToSurname: String?
    let assignedUnregisteredUser: String?
    let lastTimeWorked: String?
    let link: String?
    let siteName: String?
    let totalCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name
        case isReady
        case assignedToName
        case assignedToSurname
        case assignedUnregisteredUser
        case lastTimeWorked
        case link
        case siteName
        case totalCount
    }
    
    var formattedLastTimeWorked: String {
        formatISODateToDisplay(lastTimeWorked, fallback: String(localized: "Never"))
    }
    
    var assignedToDisplayName: String {
        if let first = assignedToName, let last = assignedToSurname, !first.isEmpty || !last.isEmpty {
            return [first, last].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        }
        if let unregistered = assignedUnregisteredUser, !unregistered.isEmpty {
            return unregistered
        }
        return String(localized: "Unassigned")
    }
}

struct TerritoryDetail: Codable, Identifiable {
    let id: String
    let name: String?
    let isReady: Bool?
    let assignedToName: String?
    let assignedToSurname: String?
    let assignedUnregisteredUser: String?
    let assignedUnregisteredUserAssignmentId: String?
    let lastTimeWorked: String?
    let link: String?
    let totalCount: Int?
    let toBoundaryPart: TerritoryBoundaryPart?
    let toParts: [TerritoryPart]?
    let toAllowedUsers: [AllowedUser]?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name
        case isReady
        case assignedToName
        case assignedToSurname
        case assignedUnregisteredUser
        case assignedUnregisteredUserAssignmentId
        case lastTimeWorked
        case link
        case totalCount
        case toBoundaryPart
        case toParts
        case toAllowedUsers
    }
    
    var assignedToDisplayName: String {
        if let first = assignedToName, let last = assignedToSurname, !first.isEmpty || !last.isEmpty {
            return [first, last].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        }
        if let unregistered = assignedUnregisteredUser, !unregistered.isEmpty {
            return unregistered
        }
        return String(localized: "Unassigned")
    }
    
    var formattedLastTimeWorked: String {
        formatISODateToDisplay(lastTimeWorked, fallback: String(localized: "Never"))
    }
}

struct TerritoryBoundaryPart: Codable, Identifiable {
    let id: String
    let coordinates: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case coordinates
    }
}

struct TerritoryPart: Codable, Identifiable {
    let id: String
    let name: String?
    let coordinates: String?
    let count: Int?
    let isBoundaries: Bool?
    let toParent: TerritoryPartParent?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name
        case coordinates
        case count
        case isBoundaries
        case toParent
    }
}

struct TerritoryPartParent: Codable, Identifiable {
    let id: String
    let toBoundaryPart: TerritoryBoundaryPart?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case toBoundaryPart
    }
}
