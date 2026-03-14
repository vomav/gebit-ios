# Authentication Usage Guide

## Overview
The app now implements real HTTP authentication with JWT token management.

## How It Works

### 1. Login Process
When the user clicks "Sign In", the app:
- Creates a POST request to `https://my-territory.app/api/auth/login`
- Sends JSON body with `login` and `password` fields
- Sets `Content-Type: application/json` header
- Waits for a 200 OK response

### 2. Token Storage
Upon successful login:
- The full JSON response is stored in `UserDefaults`
- The `accessToken` is extracted and stored separately for easy access
- Both are persisted locally for future app launches

### 3. AuthManager Class
The `AuthManager` class provides:

#### Properties
```swift
var accessToken: String?        // Quick access to JWT token
var loginResponse: LoginResponse?  // Full parsed response
var isAuthenticated: Bool       // Current auth state
var isLoading: Bool            // Loading state for UI
```

#### Methods
```swift
func login(username: String, password: String) async throws
func logout()
```

### 4. Using the Access Token
To use the JWT token in other API requests:

```swift
// Access the token
if let token = authManager.accessToken {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

Or access the full response:
```swift
if let response = authManager.loginResponse {
    print("Token: \(response.accessToken)")
    // Access other fields if you add them to LoginResponse struct
}
```

### 5. Extending LoginResponse
If your API returns additional fields, add them to the `LoginResponse` struct:

```swift
struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String?    // Add optional fields
    let userId: String?
    let email: String?
    let expiresIn: Int?
}
```

## Security Notes

- Tokens are stored in `UserDefaults` (consider using Keychain for production)
- The app automatically checks for existing tokens on launch
- Logout clears all stored credentials

## Example API Call with Token

```swift
func fetchUserData() async throws {
    guard let token = authManager.accessToken else {
        throw AuthError.notAuthenticated
    }
    
    var request = URLRequest(url: URL(string: "https://my-territory.app/api/user")!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    // Process response...
}
```

## Error Handling

The authentication system handles various errors:
- Invalid URL
- Network errors
- 401 Unauthorized (wrong credentials)
- Other HTTP status codes
- JSON decoding errors

All errors are user-friendly and displayed in the login UI.
