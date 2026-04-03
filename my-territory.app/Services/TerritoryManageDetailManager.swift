import SwiftUI
import Combine

@MainActor
class TerritoryManageDetailManager: ObservableObject {
    @Published var territory: TerritoryDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let odataService: ODataService
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    func loadTerritory(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: ODataResponse<TerritoryDetail> = try await odataService.query(
                entitySet: "Territories",
                filter: "ID eq \(id)",
                select: ["ID", "assignedToName", "assignedToSurname", "assignedUnregisteredUser", "assignedUnregisteredUserAssignmentId", "isReady", "lastTimeWorked", "link", "name", "totalCount"],
                expand: ["toBoundaryPart($select=ID,coordinates)", "toParts($orderby=name;$select=ID,coordinates,count,isBoundaries,name;$expand=toParent($select=ID;$expand=toBoundaryPart($select=ID,coordinates)))", "toAllowedUsers($orderby=surname;$select=name,surname,tenant_ID,user_ID)"],
                top: 1
            )
            
            territory = response.value.first
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading territory detail: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh(id: String) async {
        await loadTerritory(id: id)
    }
    
    func assignToUser(territoryId: String, userId: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/Territories(\(territoryId))/srv.searching.assignToUser"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters = ["userId": userId]
        request.httpBody = try JSONEncoder().encode(parameters)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadTerritory(id: territoryId)
    }
    
    func withdrawFromUser(territoryId: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/Territories(\(territoryId))/srv.searching.withdrawFromUser"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadTerritory(id: territoryId)
    }
}
