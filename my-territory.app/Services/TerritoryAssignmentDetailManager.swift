import SwiftUI
import Combine

/// Unified manager that replaces both TerritoryDetailManager and GroupTerritoryDetailManager.
/// The only difference is the `entitySet` parameter.
@MainActor
class TerritoryAssignmentDetailManager: ObservableObject {
    @Published var assignment: TerritoryAssignment?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let odataService: ODataService
    private let entitySet: String
    
    init(odataService: ODataService, entitySet: String) {
        self.odataService = odataService
        self.entitySet = entitySet
    }
    
    func loadAssignment(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: ODataResponse<TerritoryAssignment> = try await odataService.query(
                entitySet: entitySet,
                filter: "ID eq \(id)",
                select: ["ID", "availableTerritoryCount", "finishedDate", "inProgressTerritoryCount", "link", "name", "startedDate", "totalTerritoryCount", "type"],
                expand: ["toPartAssignments($expand=inWorkBy,toBoundaryPart($select=ID,coordinates);$select=ID,name,coordinates,isBoundaries,isDone;$orderby=name)"],
                top: 1
            )
            
            assignment = response.value.first
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading territory detail: \(error)")
        }
        
        isLoading = false
    }
    
    func updateType(id: String, newType: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        guard let url = URL(string: "\(AppConstants.odataBaseURL)/\(entitySet)(\(id))") else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["type": newType]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let responseBody = String(data: data, encoding: .utf8) {
                print("DEBUG: Update type error response: \(responseBody)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadAssignment(id: id)
    }
}
