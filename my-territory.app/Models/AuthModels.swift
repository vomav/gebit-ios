import Foundation

struct LoginRequest: Codable {
    let login: String
    let password: String
}

struct LoginResponse: Codable {
    let accessToken: String
}

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case loginFailed(statusCode: Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid server URL")
        case .invalidResponse:
            return String(localized: "Invalid response from server")
        case .loginFailed(let statusCode):
            if statusCode == 401 {
                return String(localized: "Invalid login or password")
            } else {
                return String(localized: "Login failed with status code: \(statusCode)")
            }
        case .decodingError:
            return String(localized: "Failed to process server response")
        }
    }
}
