# SAP BTP SDK for iOS Integration Guide

## Overview
This guide explains how to integrate the SAP BTP SDK for iOS into your project for advanced OData V4 support with metadata.

## ⚠️ Prerequisites

Before proceeding, you need:

1. **SAP Account**
   - SAP Developer account
   - Access to SAP Cloud Platform
   - Valid SAP license

2. **Development Tools**
   - Xcode 14+ 
   - CocoaPods or Swift Package Manager
   - macOS with admin privileges

3. **SAP BTP Access**
   - Active SAP BTP trial or subscription
   - Mobile Services enabled
   - OData service configured

## Installation Methods

### Method 1: CocoaPods (Recommended)

#### Step 1: Install CocoaPods
```bash
sudo gem install cocoapods
```

#### Step 2: Create Podfile
Navigate to your project directory and create a `Podfile`:

```ruby
# Podfile
platform :ios, '15.0'
use_frameworks!

target 'my-territory.app' do
  # SAP BTP SDK for iOS
  pod 'SAPFoundation', '~> 9.0'
  pod 'SAPCommon', '~> 9.0'
  pod 'SAPFiori', '~> 9.0'
  pod 'SAPOData', '~> 9.0'
  pod 'SAPOfflineOData', '~> 9.0'
  
  # Additional components (optional)
  pod 'SAPCPMS', '~> 9.0'  # Mobile Services
  pod 'SAPFoundationAuth', '~> 9.0'  # Authentication
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

#### Step 3: Install Dependencies
```bash
cd /path/to/your/project
pod install
```

#### Step 4: Open Workspace
From now on, **always** open the `.xcworkspace` file:
```bash
open my-territory.app.xcworkspace
```

### Method 2: Swift Package Manager

#### Step 1: Add Package Dependency
1. In Xcode: **File → Add Packages...**
2. Enter SAP SDK URL: `https://github.com/SAP/cloud-sdk-ios`
3. Select version 9.0 or later
4. Add to your target

#### Step 2: Import Required Packages
```swift
import SAPFoundation
import SAPOData
import SAPCommon
import SAPFiori
```

## SAP BTP SDK Components

### Core Libraries

1. **SAPFoundation**
   - Base framework
   - Logging, tracing
   - Core utilities

2. **SAPOData**
   - OData V2/V4 client
   - Metadata parsing
   - Query building
   - Code generation

3. **SAPCommon**
   - Common utilities
   - Networking
   - Security

4. **SAPFiori**
   - UI components
   - Design guidelines
   - Ready-to-use controls

5. **SAPOfflineOData**
   - Offline capability
   - Data synchronization
   - Conflict resolution

## Configuration

### 1. Setup Mobile Services

#### Create Configuration File
Create `ConfigurationProvider.swift`:

```swift
import Foundation
import SAPFoundation
import SAPCommon

class ConfigurationProvider {
    
    static let shared = ConfigurationProvider()
    
    // Your SAP Mobile Services configuration
    var serviceURL = URL(string: "https://my-territory.app")!
    var appID = "com.mycompany.territory"
    var authenticationURL = URL(string: "https://my-territory.app/oauth2/token")!
    
    // OData service configuration
    var odataServiceURL = URL(string: "https://my-territory.app/odata/v4/srv.searching")!
    
    private init() {}
}
```

### 2. Initialize SDK

Update `my_territory_appApp.swift`:

```swift
import SwiftUI
import SAPFoundation
import SAPCommon

@main
struct my_territory_appApp: App {
    
    init() {
        setupSAPSDK()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func setupSAPSDK() {
        // Initialize logging
        Logger.root.logLevel = .info
        
        // Configure network settings
        SAPURLSession.setDefaultSessionConfiguration(.default)
        
        // Setup tracking (optional)
        SAPcpmsSettings.shared.isTrackingEnabled = false
    }
}
```

### 3. Create OData Service with Metadata

#### Generate Service Classes

```bash
# Download metadata
curl https://my-territory.app/odata/v4/srv.searching/\$metadata -o metadata.xml

# Use SAP Assistant for iOS (SAP-specific tool) to generate classes
# This creates type-safe proxy classes
```

#### Manual OData Service Setup

Create `TerritoryODataService.swift`:

```swift
import Foundation
import SAPOData
import SAPCommon

class TerritoryODataService {
    
    private var dataService: OnlineODataProvider?
    private let serviceURL: URL
    
    init() {
        self.serviceURL = ConfigurationProvider.shared.odataServiceURL
        setupService()
    }
    
    private func setupService() {
        // Create service parameters
        let params = OnlineODataProviderParameters()
        params.serviceURL = serviceURL
        
        // Setup authentication (using your JWT token)
        if let token = UserDefaults.standard.string(forKey: "app.my-territory.accessToken") {
            let authHeader = "Bearer \(token)"
            params.customHeaders = ["Authorization": authHeader]
        }
        
        // Create provider
        do {
            dataService = try OnlineODataProvider(
                serviceName: "TerritoryService",
                serviceURL: serviceURL,
                parameters: params
            )
        } catch {
            print("Error creating OData provider: \(error)")
        }
    }
    
    // MARK: - Query Methods
    
    func fetchTerritoryAssignments(completion: @escaping (Result<[TerritoryAssignment], Error>) -> Void) {
        guard let service = dataService else {
            completion(.failure(NSError(domain: "OData", code: -1)))
            return
        }
        
        let query = DataQuery()
            .select("ID", "name", "type", "totalTerritoryCount")
            .expand("toPartAssignments")
            .top(20)
        
        service.loadProperty(property: TerritoryAssignment.self,
                            query: query) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let assignments = result {
                completion(.success(assignments))
            }
        }
    }
    
    func fetchPartAssignmentDetail(id: String, completion: @escaping (Result<PartAssignmentDetail, Error>) -> Void) {
        guard let service = dataService else {
            completion(.failure(NSError(domain: "OData", code: -1)))
            return
        }
        
        let query = DataQuery()
            .withKey(PartAssignmentKey.id(id))
            .select("ID", "name", "count", "isDone")
            .expand(
                "inWorkBy($orderby=surname;$select=freestyleName,id,surname,username)",
                "toAllowedUsers($orderby=surname;$select=name,surname,tenant_ID,user_ID)",
                "toBoundaryPart($select=ID,coordinates)",
                "toParent($select=ID;$expand=toTerritory($select=ID,link,name))"
            )
        
        service.loadProperty(property: PartAssignmentDetail.self,
                            query: query) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let detail = result {
                completion(.success(detail))
            }
        }
    }
}
```

### 4. Integrate with SwiftUI

Update `AuthManager` to use SAP SDK:

```swift
import SAPFoundation
import SAPCommon

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private var sapAuthenticator: SAPAuthenticator?
    
    func login(username: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Use SAP OAuth
        let auth = SAPAuthenticator(
            authURL: ConfigurationProvider.shared.authenticationURL,
            clientID: "your-client-id",
            clientSecret: "your-client-secret"
        )
        
        sapAuthenticator = auth
        
        try await auth.authenticate(username: username, password: password)
        
        // Store token
        if let token = auth.accessToken {
            UserDefaults.standard.set(token, forKey: "app.my-territory.accessToken")
            isAuthenticated = true
        }
    }
}
```

## Benefits of Using SAP BTP SDK

### 1. Type-Safe OData Access
```swift
// Auto-generated classes from metadata
let assignment = TerritoryAssignment()
assignment.name = "New Territory"
assignment.totalTerritoryCount = 10

// Type-safe queries
let query = DataQuery()
    .filter(TerritoryAssignment.name.equal("District A"))
    .expand(TerritoryAssignment.toPartAssignments)
```

### 2. Offline Capability
```swift
// Enable offline
let offlineParams = OfflineODataParameters()
offlineParams.enableOfflineStore = true

let offlineService = try OfflineODataProvider(
    serviceName: "TerritoryService",
    serviceURL: serviceURL,
    parameters: offlineParams
)

// Sync data
offlineService.download { error in
    if error == nil {
        // Data downloaded for offline use
    }
}
```

### 3. Automatic Conflict Resolution
```swift
offlineService.upload { error in
    if let error = error as? OfflineODataError {
        // Handle conflicts
        if case .conflictDetected = error {
            // Resolve using server or client version
        }
    }
}
```

### 4. Fiori UI Components
```swift
import SAPFiori

// Use pre-built SAP Fiori controls
ObjectTableViewCell()
ObjectHeader()
KPIItem()
ContactItem()
```

## Comparison: Manual vs SAP SDK

| Feature | Manual Implementation | SAP BTP SDK |
|---------|---------------------|------------|
| Setup Time | ⚡ Quick (minutes) | ⏰ Longer (hours/days) |
| Type Safety | ✅ Good | ✅✅ Excellent |
| Offline Support | ❌ Manual | ✅ Built-in |
| Metadata | ❌ Manual | ✅ Automatic |
| Code Generation | ❌ No | ✅ Yes |
| Dependencies | 0 | Many |
| Learning Curve | Low | High |
| SAP License | ❌ Not required | ✅ Required |
| Complexity | Low | High |
| Maintenance | Manual updates | Auto-sync with schema |

## Recommendation

### Use Manual Implementation (Current) If:
- ✅ Simple OData service (< 20 entities)
- ✅ No SAP license/access
- ✅ Fast development needed
- ✅ Minimal offline requirements
- ✅ Team unfamiliar with SAP

### Use SAP BTP SDK If:
- ✅ SAP ecosystem integration
- ✅ Large/complex OData schema (50+ entities)
- ✅ Offline-first requirements
- ✅ SAP Fiori design needed
- ✅ SAP license available
- ✅ Long-term SAP project

## Next Steps

### To Continue with Manual (Recommended for You):
1. ✅ Keep current implementation
2. ✅ I'll fix the enum error
3. ✅ Continue building features

### To Switch to SAP SDK:
1. Follow installation steps above
2. Contact SAP for license/access
3. Download SAP Assistant for iOS
4. Generate proxy classes from metadata
5. Refactor existing code to use SDK

## Support Resources

- **SAP Developer Center**: https://developers.sap.com
- **SAP BTP SDK Documentation**: https://help.sap.com/ios-sdk
- **SAP Community**: https://community.sap.com
- **GitHub**: https://github.com/SAP/cloud-sdk-ios

---

## My Recommendation

**Continue with the manual implementation** because:
1. Your OData service is relatively simple
2. No SAP license required
3. Faster development
4. Your current approach is working well
5. You don't need offline sync yet

The manual approach is perfectly suitable for your use case. SAP SDK would be overkill unless you're building a large enterprise SAP S/4HANA integration.

**Should I fix the enum error and continue with manual implementation?**
