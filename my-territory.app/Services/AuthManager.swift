import SwiftUI
import Combine

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let accessTokenKey = "app.my-territory.accessToken"
    private let loginResponseKey = "app.my-territory.loginResponse"
    
    init() {
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
        
        guard let url = URL(string: AppConstants.loginURL) else {
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
        UserDefaults.standard.set(response.accessToken, forKey: accessTokenKey)
        
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: loginResponseKey)
        }
    }
}
