import SwiftUI
import Combine

@MainActor
class ODataService: ObservableObject {
    let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    // MARK: - Generic OData Query
    
    func query<T: Decodable>(
        entitySet: String,
        filter: String? = nil,
        select: [String]? = nil,
        expand: [String]? = nil,
        orderBy: String? = nil,
        top: Int? = nil,
        skip: Int? = nil
    ) async throws -> ODataResponse<T> {
        guard let token = authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        var urlComponents = URLComponents(string: "\(AppConstants.odataBaseURL)/\(entitySet)")!
        var queryItems: [URLQueryItem] = []
        
        if let filter = filter {
            queryItems.append(URLQueryItem(name: "$filter", value: filter))
        }
        
        if let select = select {
            queryItems.append(URLQueryItem(name: "$select", value: select.joined(separator: ",")))
        }
        
        if let expand = expand {
            queryItems.append(URLQueryItem(name: "$expand", value: expand.joined(separator: ",")))
        }
        
        if let orderBy = orderBy {
            queryItems.append(URLQueryItem(name: "$orderby", value: orderBy))
        }
        
        if let top = top {
            queryItems.append(URLQueryItem(name: "$top", value: String(top)))
        }
        
        if let skip = skip {
            queryItems.append(URLQueryItem(name: "$skip", value: String(skip)))
        }
        
        queryItems.append(URLQueryItem(name: "$count", value: "true"))
        
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = urlComponents.url else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        return try decoder.decode(ODataResponse<T>.self, from: data)
    }
    
    // MARK: - Create Entity
    
    func create<T: Encodable>(entitySet: String, entity: T) async throws {
        guard let token = authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        guard let url = URL(string: "\(AppConstants.odataBaseURL)/\(entitySet)") else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(entity)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Update Entity
    
    func update<T: Encodable>(entitySet: String, key: String, entity: T) async throws {
        guard let token = authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        guard let url = URL(string: "\(AppConstants.odataBaseURL)/\(entitySet)(\(key))") else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(entity)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Delete Entity
    
    func delete(entitySet: String, key: String) async throws {
        guard let token = authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        guard let url = URL(string: "\(AppConstants.odataBaseURL)/\(entitySet)(\(key))") else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
}
