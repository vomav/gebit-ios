//
//  ContentView.swift
//  my-territory.app
//
//  Created by Volodymyr Voytovych on 08.03.26.
//

import SwiftUI
import MapKit
import Combine
import PhotosUI

// MARK: - Models

struct Category: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    var children: [Category]?
    var isDistrict: Bool = false
    var coordinate: CLLocationCoordinate2D?
    var region: MKCoordinateRegion?
    var polygonCoordinates: [CLLocationCoordinate2D]?
    
    // Custom hash and equality to handle CLLocationCoordinate2D
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Territory Assignment Models

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
    let inWorkBy: [InWorkBy]?  // Changed to array
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
    
    // Helper to get first worker
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

// MARK: - Part Assignment Detail Models

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
        return username ?? "Unknown"
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
        return parts.isEmpty ? "Unknown User" : parts.joined(separator: " ")
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "user_ID"  // OData field name
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

// MARK: - Auth Models

struct LoginRequest: Codable {
    let login: String
    let password: String
}

struct LoginResponse: Codable {
    let accessToken: String
    
    // Add other fields from your API response as needed
    // For example:
    // let refreshToken: String?
    // let userId: String?
    // let email: String?
}

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let loginURL = "https://my-territory.app/api/auth/login"
    private let accessTokenKey = "app.my-territory.accessToken"
    private let loginResponseKey = "app.my-territory.loginResponse"
    
    init() {
        // Check if user is already logged in
        isAuthenticated = accessToken != nil
    }
    
    // MARK: - Public Properties
    
    var accessToken: String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
    }
    
    var loginResponse: LoginResponse? {
        guard let data = UserDefaults.standard.data(forKey: loginResponseKey) else {
            return nil
        }
        return try? JSONDecoder().decode(LoginResponse.self, from: data)
    }
    
    // MARK: - Public Methods
    
    func login(username: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: loginURL) else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginRequest = LoginRequest(login: username, password: password)
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.loginFailed(statusCode: httpResponse.statusCode)
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        // Store the response persistently
        saveLoginResponse(loginResponse)
        
        isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: loginResponseKey)
        isAuthenticated = false
    }
    
    // MARK: - Private Methods
    
    private func saveLoginResponse(_ response: LoginResponse) {
        // Save the access token separately for easy access
        UserDefaults.standard.set(response.accessToken, forKey: accessTokenKey)
        
        // Save the full response
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: loginResponseKey)
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case loginFailed(statusCode: Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .loginFailed(let statusCode):
            if statusCode == 401 {
                return "Invalid login or password"
            } else {
                return "Login failed with status code: \(statusCode)"
            }
        case .decodingError:
            return "Failed to process server response"
        }
    }
}

// MARK: - OData Service Manager

@MainActor
class ODataService: ObservableObject {
    private let baseURL = "https://my-territory.app/odata/v4/srv.searching"
    let authManager: AuthManager  // Changed from private to internal (public within module)
    
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
        
        // Build OData query URL
        var urlComponents = URLComponents(string: "\(baseURL)/\(entitySet)")!
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
        
        // Add $count=true for total count
        queryItems.append(URLQueryItem(name: "$count", value: "true"))
        
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = urlComponents.url else {
            throw ODataError.invalidURL
        }
        
        // Create request with authentication
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
        
        guard let url = URL(string: "\(baseURL)/\(entitySet)") else {
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
        
        guard let url = URL(string: "\(baseURL)/\(entitySet)(\(key))") else {
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
        
        guard let url = URL(string: "\(baseURL)/\(entitySet)(\(key))") else {
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

// MARK: - OData Models

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

// MARK: - OData Errors

enum ODataError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case requestFailed(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OData URL"
        case .invalidResponse:
            return "Invalid response from OData service"
        case .unauthorized:
            return "Not authenticated. Please log in again."
        case .requestFailed(let statusCode):
            return "OData request failed with status code: \(statusCode)"
        }
    }
}

// MARK: - Territory Manager

@MainActor
class TerritoryManager: ObservableObject {
    @Published var assignments: [TerritoryAssignment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalCount: Int = 0
    
    private let odataService: ODataService
    private var currentPage = 0
    private let pageSize = 20
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    func loadMyTerritories(page: Int = 0) async {
        isLoading = true
        errorMessage = nil
        currentPage = page
        
        do {
            let response: ODataResponse<TerritoryAssignment> = try await odataService.query(
                entitySet: "TerritoryAssignments",
                select: ["ID", "availableTerritoryCount", "finishedDate", "inProgressTerritoryCount", "link", "name", "startedDate", "totalTerritoryCount", "type"],
                expand: ["toPartAssignments($expand=inWorkBy,toBoundaryPart($select=ID,coordinates);$select=ID,name,coordinates,isBoundaries,isDone;$orderby=name)"],
                top: pageSize,
                skip: page * pageSize
            )
            
            assignments = response.value
            totalCount = response.count ?? 0
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading territories: \(error)")
        }
        
        isLoading = false
    }
    
    func loadNextPage() async {
        guard !isLoading else { return }
        await loadMyTerritories(page: currentPage + 1)
    }
    
    func refresh() async {
        await loadMyTerritories(page: 0)
    }
}

// MARK: - Territory Detail Manager

@MainActor
class TerritoryDetailManager: ObservableObject {
    @Published var assignment: TerritoryAssignment?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let odataService: ODataService
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    func loadAssignment(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: ODataResponse<TerritoryAssignment> = try await odataService.query(
                entitySet: "TerritoryAssignments",
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
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        guard let url = URL(string: "\(baseURL)/TerritoryAssignments(\(id))") else {
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

// MARK: - Group Territory Manager

@MainActor
class GroupTerritoryManager: ObservableObject {
    @Published var assignments: [TerritoryAssignment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalCount: Int = 0
    
    private let odataService: ODataService
    private var currentPage = 0
    private let pageSize = 20
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    func loadGroupTerritories(page: Int = 0) async {
        isLoading = true
        errorMessage = nil
        currentPage = page
        
        do {
            let response: ODataResponse<TerritoryAssignment> = try await odataService.query(
                entitySet: "PublicTerritoryAssignments",
                select: ["ID", "availableTerritoryCount", "finishedDate", "inProgressTerritoryCount", "link", "name", "startedDate", "totalTerritoryCount", "type"],
                expand: ["toPartAssignments($expand=inWorkBy,toBoundaryPart($select=ID,coordinates);$select=ID,name,coordinates,isBoundaries,isDone;$orderby=name)"],
                top: pageSize,
                skip: page * pageSize
            )
            
            assignments = response.value
            totalCount = response.count ?? 0
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading group territories: \(error)")
        }
        
        isLoading = false
    }
    
    func loadNextPage() async {
        guard !isLoading else { return }
        await loadGroupTerritories(page: currentPage + 1)
    }
    
    func refresh() async {
        await loadGroupTerritories(page: 0)
    }
}

// MARK: - Group Territory Detail Manager

@MainActor
class GroupTerritoryDetailManager: ObservableObject {
    @Published var assignment: TerritoryAssignment?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let odataService: ODataService
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    func loadAssignment(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: ODataResponse<TerritoryAssignment> = try await odataService.query(
                entitySet: "PublicTerritoryAssignments",
                filter: "ID eq \(id)",
                select: ["ID", "availableTerritoryCount", "finishedDate", "inProgressTerritoryCount", "link", "name", "startedDate", "totalTerritoryCount", "type"],
                expand: ["toPartAssignments($expand=inWorkBy,toBoundaryPart($select=ID,coordinates);$select=ID,name,coordinates,isBoundaries,isDone;$orderby=name)"],
                top: 1
            )
            
            assignment = response.value.first
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading group territory detail: \(error)")
        }
        
        isLoading = false
    }
    
    func updateType(id: String, newType: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        guard let url = URL(string: "\(baseURL)/PublicTerritoryAssignments(\(id))") else {
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
                print("DEBUG: Update group type error response: \(responseBody)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        await loadAssignment(id: id)
    }
}

// MARK: - Part Assignment Manager

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
            // Build the custom URL for single item query
            guard let token = odataService.authManager.accessToken else {
                throw ODataError.unauthorized
            }
            
            let baseURL = "https://my-territory.app/odata/v4/srv.searching"
            
            // Build URL without quotes around the GUID
            guard var urlComponents = URLComponents(string: "\(baseURL)/PartAssignments(\(id))") else {
                throw ODataError.invalidURL
            }
            
            // Add query parameters
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
            
            // Debug: Print response details
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
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        let urlString = "\(baseURL)/PartAssignments(\(id))"
        
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
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        let urlString = "\(baseURL)/PartAssignments(\(id))"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        print("DEBUG: Toggle done URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Toggle the current status
        let newStatus = !currentStatus
        let body = ["isDone": newStatus]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("DEBUG: PATCH body: {\"isDone\": \(newStatus)}")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        // Debug: Print response details if error
        if !(200...299).contains(httpResponse.statusCode) {
            if let responseBody = String(data: data, encoding: .utf8) {
                print("DEBUG: Toggle done error response: \(responseBody)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        // Refresh the data
        await loadPartAssignment(id: id)
    }
    
    func assignToMe(id: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        let urlString = "\(baseURL)/PartAssignments(\(id))/srv.searching.assignPartToMe"
        
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
        
        // Refresh the data
        await loadPartAssignment(id: id)
    }
    
    func assignToUser(id: String, userId: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        let urlString = "\(baseURL)/PartAssignments(\(id))/srv.searching.assignPartToUser"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Send userId as parameter
        let parameters = ["userId": userId]
        request.httpBody = try JSONEncoder().encode(parameters)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ODataError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ODataError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        // Refresh the data
        await loadPartAssignment(id: id)
    }
    
    func removeWorker(partAssignmentId: String, inWorkById: String) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        let urlString = "\(baseURL)/InWorkBy(\(inWorkById))"
        
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
        
        // Refresh the data
        await loadPartAssignment(id: partAssignmentId)
    }
    
    func uploadImage(id: String, imageData: Data) async throws {
        guard let token = odataService.authManager.accessToken else {
            throw ODataError.unauthorized
        }
        
        let baseURL = "https://my-territory.app/odata/v4/srv.searching"
        let urlString = "\(baseURL)/PartAssignments(\(id))/srv.searching.uploadImage"
        
        guard let url = URL(string: urlString) else {
            throw ODataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Send image as data URL (base64 with MIME prefix)
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
        
        // Refresh the data to get the updated workedPartImageUrl
        await loadPartAssignment(id: id)
    }
}

// MARK: - Sample Data

extension ContentView {
    static let sampleCategories = [
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

// MARK: - Main View

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        if authManager.isAuthenticated {
            HomeScreen()
                .environmentObject(authManager)
        } else {
            LoginView()
                .environmentObject(authManager)
        }
    }
}

// MARK: - Home Screen

struct HomeScreen: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var navigateToMyTerritories = false
    @State private var navigateToGroupTerritories = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "map.circle.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Welcome!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Choose your territory type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 80)
                    .padding(.bottom, 60)
                    
                    // Buttons Section
                    VStack(spacing: 20) {
                        // My Territories Button
                        NavigationLink(destination: TerritoriesView(isGroupMode: false, authManager: authManager)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title)
                                        Text("My Territories")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                    Text("Manage your personal territories")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .background(Color(uiColor: .systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Group Territories Button
                        NavigationLink(destination: TerritoriesView(isGroupMode: true, authManager: authManager)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "person.3.fill")
                                            .font(.title)
                                        Text("Group Territories")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                    Text("View and manage group territories")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .background(Color(uiColor: .systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        authManager.logout()
                    }) {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
}

// MARK: - Territories View

struct TerritoriesView: View {
    @EnvironmentObject var authManager: AuthManager
    let isGroupMode: Bool
    @StateObject private var territoryManager: TerritoryManager
    @StateObject private var groupTerritoryManager: GroupTerritoryManager
    
    init(isGroupMode: Bool, authManager: AuthManager) {
        self.isGroupMode = isGroupMode
        let odataService = ODataService(authManager: authManager)
        _territoryManager = StateObject(wrappedValue: TerritoryManager(odataService: odataService))
        _groupTerritoryManager = StateObject(wrappedValue: GroupTerritoryManager(odataService: odataService))
    }
    
    private var assignments: [TerritoryAssignment] {
        isGroupMode ? groupTerritoryManager.assignments : territoryManager.assignments
    }
    
    private var isLoading: Bool {
        isGroupMode ? groupTerritoryManager.isLoading : territoryManager.isLoading
    }
    
    private var errorMessage: String? {
        isGroupMode ? groupTerritoryManager.errorMessage : territoryManager.errorMessage
    }
    
    private var totalCount: Int {
        isGroupMode ? groupTerritoryManager.totalCount : territoryManager.totalCount
    }
    
    var body: some View {
        Group {
            if isLoading && assignments.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let errorMessage = errorMessage {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Error Loading Territories")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task {
                                if isGroupMode {
                                    await groupTerritoryManager.refresh()
                                } else {
                                    await territoryManager.refresh()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if assignments.isEmpty {
                ContentUnavailableView(
                    "No Territories",
                    systemImage: "map",
                    description: Text("There are no territories assigned yet.")
                )
            } else {
                List {
                    ForEach(assignments) { assignment in
                        if isGroupMode {
                            NavigationLink(destination: GroupTerritoryDetailView(assignment: assignment, authManager: authManager)) {
                                TerritoryAssignmentRow(assignment: assignment)
                            }
                        } else {
                            NavigationLink(destination: TerritoryDetailView(assignment: assignment, authManager: authManager)) {
                                TerritoryAssignmentRow(assignment: assignment)
                            }
                        }
                    }
                    
                    // Load more button
                    if assignments.count < totalCount {
                        HStack {
                            Spacer()
                            Button("Load More") {
                                Task {
                                    if isGroupMode {
                                        await groupTerritoryManager.loadNextPage()
                                    } else {
                                        await territoryManager.loadNextPage()
                                    }
                                }
                            }
                            .disabled(isLoading)
                            Spacer()
                        }
                        .padding()
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(isGroupMode ? "Group Territories" : "My Territories")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if isGroupMode {
                await groupTerritoryManager.refresh()
            } else {
                await territoryManager.refresh()
            }
        }
        .task {
            if isGroupMode {
                await groupTerritoryManager.loadGroupTerritories()
            } else {
                await territoryManager.loadMyTerritories()
            }
        }
        .overlay {
            if isLoading && !assignments.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(10)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Territory Assignment Row

struct TerritoryAssignmentRow: View {
    let assignment: TerritoryAssignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.name)
                        .font(.headline)
                    
                    if let type = assignment.type {
                        Text(type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if assignment.finishedDate != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            // Statistics
            HStack(spacing: 16) {
                if let total = assignment.totalTerritoryCount {
                    StatBadge(
                        icon: "map",
                        label: "Total",
                        value: "\(total)",
                        color: .blue
                    )
                }
                
                if let inProgress = assignment.inProgressTerritoryCount {
                    StatBadge(
                        icon: "clock",
                        label: "In Progress",
                        value: "\(inProgress)",
                        color: .orange
                    )
                }
                
                if let available = assignment.availableTerritoryCount {
                    StatBadge(
                        icon: "checkmark.circle",
                        label: "Available",
                        value: "\(available)",
                        color: .green
                    )
                }
            }
            
            // Dates
            if let startedDate = assignment.startedDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Started: \(formatDate(startedDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try ISO8601 format first
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd-MM-yyyy"
            return displayFormatter.string(from: date)
        }
        
        // Try other common formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "dd-MM-yyyy"
                return displayFormatter.string(from: date)
            }
        }
        
        // Return original string if parsing fails
        return dateString
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Screenshot Modal View

struct ScreenshotModalView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            VStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading screenshot...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 12)
                                Spacer()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: geometry.size.width * scale,
                                    height: geometry.size.height * scale
                                )
                                .gesture(
                                    MagnifyGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value.magnification
                                            scale = min(max(newScale, 1.0), 5.0)
                                        }
                                        .onEnded { value in
                                            let newScale = lastScale * value.magnification
                                            scale = min(max(newScale, 1.0), 5.0)
                                            lastScale = scale
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation {
                                        if scale > 1.0 {
                                            scale = 1.0
                                            lastScale = 1.0
                                        } else {
                                            scale = 2.5
                                            lastScale = 2.5
                                        }
                                    }
                                }
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Failed to load screenshot")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private func isImageURL(_ urlString: String) -> Bool {
    let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic", "heif", "svg"]
    let lowered = urlString.lowercased()
    return imageExtensions.contains { lowered.hasSuffix(".\($0)") || lowered.contains(".\($0)?") || lowered.contains(".\($0)&") }
}

// MARK: - Territory Detail View

struct TerritoryDetailView: View {
    let assignmentId: String
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var detailManager: TerritoryDetailManager
    @State private var selectedType: String
    @State private var isUpdatingType = false
    @State private var showScreenshotModal = false
    private let initialAssignment: TerritoryAssignment
    
    init(assignment: TerritoryAssignment, authManager: AuthManager) {
        self.assignmentId = assignment.id
        self.initialAssignment = assignment
        _selectedType = State(initialValue: assignment.type ?? "Personal")
        let odataService = ODataService(authManager: authManager)
        _detailManager = StateObject(wrappedValue: TerritoryDetailManager(odataService: odataService))
    }
    
    private var assignment: TerritoryAssignment {
        detailManager.assignment ?? initialAssignment
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    Text(assignment.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Picker("Type", selection: $selectedType) {
                        Text("Personal").tag("Personal")
                        Text("Public").tag("Public")
                    }
                    .pickerStyle(.segmented)
                    .disabled(isUpdatingType)
                    .onChange(of: selectedType) { oldValue, newValue in
                        guard oldValue != newValue else { return }
                        isUpdatingType = true
                        Task {
                            do {
                                try await detailManager.updateType(id: assignmentId, newType: newValue)
                            } catch {
                                // Revert on failure
                                selectedType = oldValue
                            }
                            isUpdatingType = false
                        }
                    }
                    
                    if let link = assignment.link, let url = URL(string: link) {
                        if isImageURL(link) {
                            Button {
                                showScreenshotModal = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("View Screenshot")
                                }
                            }
                        } else {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Open Link")
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Overview Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overview")
                        .font(.headline)
                    
                    if let total = assignment.totalTerritoryCount {
                        StatRow(label: "Total Territories", value: "\(total)", icon: "map")
                    }
                    if let inProgress = assignment.inProgressTerritoryCount {
                        StatRow(label: "In Progress", value: "\(inProgress)", icon: "clock")
                    }
                    if let available = assignment.availableTerritoryCount {
                        StatRow(label: "Available", value: "\(available)", icon: "checkmark.circle")
                    }
                    
                    if assignment.startedDate != nil || assignment.finishedDate != nil {
                        Divider()
                    }
                    
                    if let started = assignment.startedDate {
                        StatRow(label: "Started", value: formatDateDDMMYYYY(started), icon: "calendar")
                    }
                    if let finished = assignment.finishedDate {
                        StatRow(label: "Finished", value: formatDateDDMMYYYY(finished), icon: "checkmark.circle")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Part Assignments Table
                if let partAssignments = assignment.toPartAssignments, !partAssignments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Part Assignments (\(partAssignments.count))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Table Rows
                        ForEach(partAssignments) { part in
                            NavigationLink(destination: PartAssignmentDetailView(
                                partAssignmentId: part.id,
                                authManager: authManager
                            )) {
                                VStack(spacing: 0) {
                                    // Map preview
                                    PartAssignmentMapPreview(
                                        partCoordinates: part.coordinates,
                                        boundaryCoordinates: part.toBoundaryPart?.coordinates
                                    )
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    
                                    // Row info
                                    HStack(spacing: 12) {
                                        // Status indicator
                                        Circle()
                                            .fill(part.isDone == true ? Color.gray : (part.inWorkBy?.isEmpty ?? true) ? Color.green : Color.orange)
                                            .frame(width: 8, height: 8)
                                        
                                        // Name
                                        Text(part.name ?? "Part \(part.id)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        // Assigned To
                                        if let workers = part.inWorkBy, !workers.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "person.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(workers.compactMap(\.name).prefix(2).joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                if workers.count > 2 {
                                                    Text("+\(workers.count - 2)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        } else {
                                            Text("Unassigned")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }
                                .background(Color(uiColor: .systemBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if part.id != partAssignments.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Territory Details")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await detailManager.loadAssignment(id: assignmentId)
        }
        .task {
            await detailManager.loadAssignment(id: assignmentId)
            if let type = detailManager.assignment?.type {
                selectedType = type
            }
        }
        .sheet(isPresented: $showScreenshotModal) {
            if let link = assignment.link, let url = URL(string: link) {
                ScreenshotModalView(imageURL: url)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDateDDMMYYYY(_ dateString: String) -> String {
        // Try ISO8601 format first
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd-MM-yyyy"
            return displayFormatter.string(from: date)
        }
        
        // Try other common formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "dd-MM-yyyy"
                return displayFormatter.string(from: date)
            }
        }
        
        // Return original string if parsing fails
        return dateString
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Group Territory Detail View

struct GroupTerritoryDetailView: View {
    let assignmentId: String
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var detailManager: GroupTerritoryDetailManager
    @State private var selectedType: String
    @State private var isUpdatingType = false
    @State private var showScreenshotModal = false
    private let initialAssignment: TerritoryAssignment
    
    init(assignment: TerritoryAssignment, authManager: AuthManager) {
        self.assignmentId = assignment.id
        self.initialAssignment = assignment
        _selectedType = State(initialValue: assignment.type ?? "Personal")
        let odataService = ODataService(authManager: authManager)
        _detailManager = StateObject(wrappedValue: GroupTerritoryDetailManager(odataService: odataService))
    }
    
    private var assignment: TerritoryAssignment {
        detailManager.assignment ?? initialAssignment
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    Text(assignment.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let link = assignment.link, let url = URL(string: link) {
                        if isImageURL(link) {
                            Button {
                                showScreenshotModal = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("View Screenshot")
                                }
                            }
                        } else {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Open Link")
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Overview Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overview")
                        .font(.headline)
                    
                    if let total = assignment.totalTerritoryCount {
                        StatRow(label: "Total Territories", value: "\(total)", icon: "map")
                    }
                    if let inProgress = assignment.inProgressTerritoryCount {
                        StatRow(label: "In Progress", value: "\(inProgress)", icon: "clock")
                    }
                    if let available = assignment.availableTerritoryCount {
                        StatRow(label: "Available", value: "\(available)", icon: "checkmark.circle")
                    }
                    
                    if assignment.startedDate != nil || assignment.finishedDate != nil {
                        Divider()
                    }
                    
                    if let started = assignment.startedDate {
                        StatRow(label: "Started", value: formatGroupDateDDMMYYYY(started), icon: "calendar")
                    }
                    if let finished = assignment.finishedDate {
                        StatRow(label: "Finished", value: formatGroupDateDDMMYYYY(finished), icon: "checkmark.circle")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Part Assignments Table
                if let partAssignments = assignment.toPartAssignments, !partAssignments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Part Assignments (\(partAssignments.count))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(partAssignments) { part in
                            NavigationLink(destination: PartAssignmentDetailView(
                                partAssignmentId: part.id,
                                authManager: authManager
                            )) {
                                VStack(spacing: 0) {
                                    // Map preview
                                    PartAssignmentMapPreview(
                                        partCoordinates: part.coordinates,
                                        boundaryCoordinates: part.toBoundaryPart?.coordinates
                                    )
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    
                                    // Row info
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(part.isDone == true ? Color.gray : (part.inWorkBy?.isEmpty ?? true) ? Color.green : Color.orange)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(part.name ?? "Part \(part.id)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        if let workers = part.inWorkBy, !workers.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "person.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(workers.compactMap(\.name).prefix(2).joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                if workers.count > 2 {
                                                    Text("+\(workers.count - 2)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        } else {
                                            Text("Unassigned")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }
                                .background(Color(uiColor: .systemBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if part.id != partAssignments.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Group Territory Details")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await detailManager.loadAssignment(id: assignmentId)
        }
        .task {
            await detailManager.loadAssignment(id: assignmentId)
            if let type = detailManager.assignment?.type {
                selectedType = type
            }
        }
        .sheet(isPresented: $showScreenshotModal) {
            if let link = assignment.link, let url = URL(string: link) {
                ScreenshotModalView(imageURL: url)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatGroupDateDDMMYYYY(_ dateString: String) -> String {
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd-MM-yyyy"
            return displayFormatter.string(from: date)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "dd-MM-yyyy"
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username
        case password
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("My Territory")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 50)
                
                // Login Form
                VStack(spacing: 20) {
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Login")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: "person")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            TextField("Enter your login", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            SecureField("Enter your password", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    performLogin()
                                }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    
                    // Error Message
                    if showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Login Button
                    Button(action: performLogin) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Signing In...")
                                    .fontWeight(.semibold)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
                    .opacity(username.isEmpty || password.isEmpty || authManager.isLoading ? 0.6 : 1.0)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("Need help? Contact support")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    private func performLogin() {
        Task {
            do {
                try await authManager.login(username: username, password: password)
                // Success - authManager.isAuthenticated will be true
                // and the view will automatically transition
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                
                // Hide error after 3 seconds
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        showError = false
                    }
                }
            }
        }
    }
}

// MARK: - District Map View

struct DistrictMapView: View {
    let category: Category
    @State private var position: MapCameraPosition
    
    init(category: Category) {
        self.category = category
        if let region = category.region {
            _position = State(initialValue: .region(region))
        } else if let coordinate = category.coordinate {
            _position = State(initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            ))
        } else {
            _position = State(initialValue: .automatic)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title)
                    .foregroundStyle(.tint)
                
                VStack(alignment: .leading) {
                    Text(category.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("District Territory Map")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            // Map
            Map(position: $position) {
                if let coordinate = category.coordinate {
                    Marker(category.name, systemImage: "building.2.fill", coordinate: coordinate)
                        .tint(.blue)
                }
                
                // Show polygon if available
                if let polygonCoords = category.polygonCoordinates, !polygonCoords.isEmpty {
                    MapPolygon(coordinates: polygonCoords)
                        .foregroundStyle(.blue.opacity(0.3))
                        .stroke(.blue, lineWidth: 2)
                } else if let coordinate = category.coordinate {
                    // Fallback to circle if no polygon
                    MapCircle(center: coordinate, radius: 1000)
                        .foregroundStyle(.blue.opacity(0.2))
                        .stroke(.blue, lineWidth: 2)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            
            // Info Panel
            VStack(alignment: .leading, spacing: 12) {
                Text("Territory Information")
                    .font(.headline)
                
                if let coordinate = category.coordinate {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.secondary)
                        Text("Latitude: \(coordinate.latitude, specifier: "%.4f")")
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.secondary)
                        Text("Longitude: \(coordinate.longitude, specifier: "%.4f")")
                    }
                    .font(.subheadline)
                }
                
                Divider()
                
                Text("Use the map controls to explore the territory. You can zoom, rotate, and switch between different map views.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .navigationTitle(category.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Detail View

struct DetailView: View {
    let category: Category
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    
                    VStack(alignment: .leading) {
                        Text(category.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let children = category.children {
                            Text("\(children.count) sub-items")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Content Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("This is the content area for **\(category.name)**. You can display any relevant information, forms, or data visualizations here.")
                        .font(.body)
                    
                    if let children = category.children, !children.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sub-items:")
                                .font(.headline)
                                .padding(.top, 8)
                            
                            ForEach(children) { child in
                                HStack {
                                    Image(systemName: child.icon)
                                        .foregroundStyle(.secondary)
                                    Text(child.name)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(category.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Coordinate Helpers

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

// MARK: - Part Assignment Map Preview

struct PartAssignmentMapPreview: View {
    let partCoordinates: String?
    let boundaryCoordinates: String?
    
    var body: some View {
        let partCoords = parseCoordinateString(partCoordinates)
        let boundaryCoords = parseCoordinateString(boundaryCoordinates)
        let allCoords = (partCoords ?? []) + (boundaryCoords ?? [])
        
        if !allCoords.isEmpty {
            let region = calculateMapRegion(for: allCoords)
            
            Map(initialPosition: .region(region), interactionModes: []) {
                if let coords = partCoords, !coords.isEmpty {
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(.blue.opacity(0.25))
                        .stroke(.blue, lineWidth: 1.5)
                }
                
                if let coords = boundaryCoords, !coords.isEmpty {
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(.red.opacity(0.15))
                        .stroke(.red, lineWidth: 1.5)
                }
            }
            .mapStyle(.standard)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Part Assignment Detail View

struct PartAssignmentDetailView: View {
    let partAssignmentId: String
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager: PartAssignmentManager
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showAssignSheet = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var workerToRemove: WorkerDetail?
    @State private var selectedTab = 0
    @State private var showScreenshotModal = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploading = false
    
    init(partAssignmentId: String, authManager: AuthManager) {
        self.partAssignmentId = partAssignmentId
        let odataService = ODataService(authManager: authManager)
        _manager = StateObject(wrappedValue: PartAssignmentManager(odataService: odataService))
    }
    
    var body: some View {
        Group {
            if manager.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            } else if let errorMessage = manager.errorMessage {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Error Loading Part Assignment")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task {
                                await manager.refresh(id: partAssignmentId)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            } else if let part = manager.partAssignment {
                VStack(spacing: 0) {
                    // Icon Tab Bar
                    HStack(spacing: 0) {
                        tabBarButton(title: "Details", icon: "doc.text.magnifyingglass", tag: 0)
                        tabBarButton(title: "Map", icon: "mappin.circle", tag: 1)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        // MARK: Details Tab
                        detailsTabContent(part: part)
                            .tag(0)
                        
                        // MARK: Map Tab
                        mapTabContent(part: part)
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "doc",
                    description: Text("Part assignment data could not be loaded.")
                )
            }
        }
        .navigationTitle("Part Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await manager.refresh(id: partAssignmentId)
        }
        .task {
            await manager.loadPartAssignment(id: partAssignmentId)
        }
        .sheet(isPresented: $showAssignSheet) {
            if let part = manager.partAssignment {
                UserSelectionSheet(
                    allowedUsers: part.toAllowedUsers ?? [],
                    onSelect: { user in
                        showAssignSheet = false
                        Task {
                            await assignToUser(userId: user.id)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showScreenshotModal) {
            if let part = manager.partAssignment,
               let imageUrl = part.workedPartImageUrl,
               let url = URL(string: imageUrl) {
                ScreenshotModalView(imageURL: url)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadSelectedPhoto(item: newItem)
                selectedPhotoItem = nil
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Remove Worker", isPresented: Binding(
            get: { workerToRemove != nil },
            set: { if !$0 { workerToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                workerToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let worker = workerToRemove {
                    workerToRemove = nil
                    Task {
                        await removeWorker(inWorkById: worker.id)
                    }
                }
            }
        } message: {
            if let worker = workerToRemove {
                Text("Are you sure you want to remove \(worker.displayName) from this part assignment?")
            }
        }
    }
    
    // MARK: - Tab Bar
    
    private func tabBarButton(title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .stroke(selectedTab == tag ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                    .foregroundStyle(selectedTab == tag ? .blue : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(selectedTab == tag ? .semibold : .regular)
                    .foregroundStyle(selectedTab == tag ? .blue : .secondary)
                
                Rectangle()
                    .fill(selectedTab == tag ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 80)
    }
    
    // MARK: - Details Tab
    
    @ViewBuilder
    private func detailsTabContent(part: PartAssignmentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Assignment Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Assignment")
                        .font(.headline)
                    
                    // Assign row
                    HStack(alignment: .top) {
                        Text("Assign:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        VStack(spacing: 8) {
                            // Assign to Me
                            Button(action: {
                                Task { await assignToMe() }
                            }) {
                                HStack {
                                    Image(systemName: "person.fill")
                                    Text("Assign to Me")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isProcessing)
                            
                            // Assign to User
                            if let allowedUsers = part.toAllowedUsers, !allowedUsers.isEmpty {
                                Button(action: {
                                    showAssignSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                        Text("Assign to User")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.purple)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(isProcessing)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Assigned to row
                    HStack(alignment: .top) {
                        Text("Assigned to:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        if let workers = part.inWorkBy, !workers.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(workers) { worker in
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundStyle(.blue)
                                        
                                        Text(worker.displayName)
                                            .font(.subheadline)
                                        
                                        if let username = worker.username {
                                            Text("@\(username)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(role: .destructive) {
                                            workerToRemove = worker
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isProcessing)
                                    }
                                }
                            }
                        } else {
                            Text("Unassigned")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Progress Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Progress")
                        .font(.headline)
                    
                    // Done row
                    HStack {
                        Text("Done:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        Button(action: {
                            Task { await toggleDoneStatus(part: part) }
                        }) {
                            Image(systemName: part.isDone == true ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(part.isDone == true ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Count row
                    HStack {
                        Text("Count:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        HStack(spacing: 0) {
                            Button {
                                let current = part.count ?? 0
                                guard current > 0 else { return }
                                Task { await updateCount(newCount: current - 1) }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.body)
                                    .frame(width: 44, height: 36)
                                    .foregroundStyle(part.count ?? 0 > 0 ? .primary : .tertiary)
                            }
                            .disabled((part.count ?? 0) <= 0)
                            
                            Text("\(part.count ?? 0)")
                                .font(.body)
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .frame(minWidth: 44)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                let current = part.count ?? 0
                                Task { await updateCount(newCount: current + 1) }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.body)
                                    .frame(width: 44, height: 36)
                            }
                        }
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                        )
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Screenshots row
                    HStack {
                        Text("Screenshots:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        if let imageUrl = part.workedPartImageUrl, URL(string: imageUrl) != nil {
                            Button {
                                showScreenshotModal = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo")
                                    Text("View")
                                }
                                .font(.subheadline)
                            }
                        } else {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            HStack(spacing: 4) {
                                if isUploading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                Text(isUploading ? "Uploading..." : "Upload")
                            }
                            .font(.subheadline)
                        }
                        .disabled(isProcessing || isUploading)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // External Resources Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("External Resources")
                        .font(.headline)
                    
                    HStack {
                        Text("forebears.io:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        Link("Link", destination: URL(string: "https://forebears.io")!)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    // MARK: - Map Tab
    
    @ViewBuilder
    private func mapTabContent(part: PartAssignmentDetail) -> some View {
        if hasCoordinates(part: part) {
            VStack(spacing: 0) {
                Map(position: $mapPosition) {
                    if let coords = parseCoordinateString(part.coordinates), !coords.isEmpty {
                        MapPolygon(coordinates: coords)
                            .foregroundStyle(.blue.opacity(0.2))
                            .stroke(.blue, lineWidth: 2.5)
                    }
                    
                    if let boundaryCoords = parseCoordinateString(part.toBoundaryPart?.coordinates), !boundaryCoords.isEmpty {
                        MapPolygon(coordinates: boundaryCoords)
                            .foregroundStyle(.red.opacity(0.15))
                            .stroke(.red, lineWidth: 2.5)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .task {
                    let allCoords = getAllCoordinates(part: part)
                    if !allCoords.isEmpty {
                        mapPosition = .region(calculateMapRegion(for: allCoords))
                    }
                }
                
                // Legend
                HStack(spacing: 20) {
                    if parseCoordinateString(part.coordinates) != nil {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(.blue.opacity(0.2))
                                .stroke(.blue, lineWidth: 2)
                                .frame(width: 24, height: 16)
                            Text("Part Assignment")
                                .font(.caption)
                        }
                    }
                    
                    if parseCoordinateString(part.toBoundaryPart?.coordinates) != nil {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(.red.opacity(0.15))
                                .stroke(.red, lineWidth: 2)
                                .frame(width: 24, height: 16)
                            Text("Boundary")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
            }
        } else {
            ContentUnavailableView(
                "No Map Data",
                systemImage: "map",
                description: Text("No coordinates available for this part assignment.")
            )
        }
    }
    
    // MARK: - Action Methods
    
    private func toggleDoneStatus(part: PartAssignmentDetail) async {
        do {
            try await manager.toggleDone(id: partAssignmentId, currentStatus: part.isDone ?? false)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func assignToMe() async {
        isProcessing = true
        do {
            try await manager.assignToMe(id: partAssignmentId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    private func assignToUser(userId: String) async {
        isProcessing = true
        do {
            try await manager.assignToUser(id: partAssignmentId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    private func updateCount(newCount: Int) async {
        do {
            try await manager.updateCount(id: partAssignmentId, newCount: newCount)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func removeWorker(inWorkById: String) async {
        isProcessing = true
        do {
            try await manager.removeWorker(partAssignmentId: partAssignmentId, inWorkById: inWorkById)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    private func uploadSelectedPhoto(item: PhotosPickerItem) async {
        isUploading = true
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ODataError.invalidResponse
            }
            
            guard var uiImage = UIImage(data: data) else {
                throw ODataError.invalidResponse
            }
            
            // Downscale if the image is larger than 1280px on any side
            let maxDimension: CGFloat = 1280
            let originalSize = uiImage.size
            if originalSize.width > maxDimension || originalSize.height > maxDimension {
                let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
                let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                uiImage = renderer.image { _ in
                    uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
            }
            
            // Target ~700 KB so the base64 payload stays under 1 MB
            let maxSize = 700_000
            var quality: CGFloat = 0.7
            guard var jpegData = uiImage.jpegData(compressionQuality: quality) else {
                throw ODataError.invalidResponse
            }
            while jpegData.count > maxSize && quality > 0.1 {
                quality -= 0.1
                if let reduced = uiImage.jpegData(compressionQuality: quality) {
                    jpegData = reduced
                }
            }
            
            try await manager.uploadImage(id: partAssignmentId, imageData: jpegData)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUploading = false
    }
    
    // MARK: - Helper Methods
    
    private func hasCoordinates(part: PartAssignmentDetail) -> Bool {
        let hasPart = part.coordinates != nil && !part.coordinates!.isEmpty
        let hasBoundary = part.toBoundaryPart?.coordinates != nil && !part.toBoundaryPart!.coordinates!.isEmpty
        return hasPart || hasBoundary
    }
    
    private func getAllCoordinates(part: PartAssignmentDetail) -> [CLLocationCoordinate2D] {
        (parseCoordinateString(part.coordinates) ?? []) +
        (parseCoordinateString(part.toBoundaryPart?.coordinates) ?? [])
    }
}

// MARK: - User Selection Sheet

struct UserSelectionSheet: View {
    let allowedUsers: [AllowedUser]
    let onSelect: (AllowedUser) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(allowedUsers) { user in
                Button(action: {
                    onSelect(user)
                }) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text(user.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ContentView()
}
