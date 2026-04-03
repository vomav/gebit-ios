import SwiftUI
import Combine

@MainActor
class PartAssignmentManager: ObservableObject {
    @Published var partAssignment: PartAssignmentDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let odataService: ODataService
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    func loadPartAssignment(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let token = odataService.authManager.accessToken else {
                throw ODataError.unauthorized
            }
            
            guard var urlComponents = URLComponents(string: "\(AppConstants.odataBaseURL)/PartAssignments(\(id))") else {
                throw ODataError.invalidURL
            }
            
            urlComponents.queryItems = [
                URLQueryItem(name: "$select", value: "ID,coordinates,count,isDone,name,workedPartImageUrl"),
                URLQueryItem(name: "$expand", value: "inWorkBy($orderby=surname;$select=freestyleName,id,surname,username),toAllowedUsers($orderby=surname;$select=name,surname,tenant_ID,user_ID),toBoundaryPart($select=ID,coordinates),toParent($select=ID;$expand=toTerritory($select=ID,link,name))")
            ]
            
            guard let url = urlComponents.url else {
                throw ODataError.invalidURL
            }
            
            print("DEBUG: Requesting part assignment with URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ODataError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("DEBUG: Error response body: \(responseBody)")
                }
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            partAssignment = try decoder.decode(PartAssignmentDetail.self, from: data)
            
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading part assignment: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh(id: String) async {
        await loadPartAssignment(id: id)
    }
    
    // MARK: - OData Actions
    
    func updateCount(id: String, newCount: Int) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/PartAssignments(\(id))"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["count": newCount]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let responseBody = String(data: data, encoding: .utf8) {
                print("DEBUG: Update count error response: \(responseBody)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadPartAssignment(id: id)
    }
    
    func toggleDone(id: String, currentStatus: Bool) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/PartAssignments(\(id))"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        print("DEBUG: Toggle done URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let newStatus = !currentStatus
        let body = ["isDone": newStatus]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("DEBUG: PATCH body: {\"isDone\": \(newStatus)}")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let responseBody = String(data: data, encoding: .utf8) {
                print("DEBUG: Toggle done error response: \(responseBody)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadPartAssignment(id: id)
    }
    
    func assignToMe(id: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/PartAssignments(\(id))/srv.searching.assignPartToMe"
        
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
        
        await loadPartAssignment(id: id)
    }
    
    func assignToUser(id: String, userId: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/PartAssignments(\(id))/srv.searching.assignPartToUser"
        
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
        
        await loadPartAssignment(id: id)
    }
    
    func removeWorker(partAssignmentId: String, inWorkById: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/InWorkBy(\(inWorkById))"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let responseBody = String(data: data, encoding: .utf8) {
                print("DEBUG: Remove worker error response: \(responseBody)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadPartAssignment(id: partAssignmentId)
    }
    
    func uploadImage(id: String, imageData: Data) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let urlString = "\(AppConstants.odataBaseURL)/PartAssignments(\(id))/srv.searching.uploadImage"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64String = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"
        let body: [String: String] = ["file": dataURL]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let responseBody = String(data: data, encoding: .utf8) {
                print("DEBUG: Upload image error response: \(responseBody)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadPartAssignment(id: id)
    }
}
