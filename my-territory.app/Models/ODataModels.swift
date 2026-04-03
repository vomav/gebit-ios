import Foundation

struct ODataResponse<T: Decodable>: Decodable {
    let context: String?
    let count: Int?
    let value: [T]
    
    enum CodingKeys: String, CodingKey {
        case context = "@odata.context"
        case count = "@odata.count"
        case value
    }
}

enum ODataError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case requestFailed(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid OData URL")
        case .invalidResponse:
            return String(localized: "Invalid response from OData service")
        case .unauthorized:
            return String(localized: "Not authenticated. Please log in again.")
        case .requestFailed(let statusCode):
            return String(localized: "OData request failed with status code: \(statusCode)")
        }
    }
}

enum TerritoryAssignmentFilter: String, CaseIterable {
    case all = "All"
    case assigned = "Assigned"
    case available = "Available"
    
    var localizedName: String {
        switch self {
        case .all: return String(localized: "All")
        case .assigned: return String(localized: "Assigned")
        case .available: return String(localized: "Available")
        }
    }
}
