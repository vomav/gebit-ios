# OData V4 Service Integration Guide

## Overview
The app now includes a comprehensive OData V4 service client that supports all standard CRUD operations with full query capabilities.

**Base URL:** `https://my-territory.app/odata/v4/srv.searching`

## Features

### ✅ OData V4 Query Options Support
- `$filter` - Filter collections
- `$select` - Choose specific fields
- `$expand` - Include related entities
- `$orderby` - Sort results
- `$top` - Limit results
- `$skip` - Pagination
- `$count` - Get total count

### ✅ CRUD Operations
- **CREATE** - POST new entities
- **READ** - GET entities with query options
- **UPDATE** - PATCH existing entities
- **DELETE** - DELETE entities

### ✅ Authentication
- Automatic JWT token injection
- Bearer token authentication
- Session management

## Usage Examples

### 1. Setup OData Service

```swift
@StateObject private var authManager = AuthManager()
@StateObject private var odataService: ODataService

init() {
    let auth = AuthManager()
    _authManager = StateObject(wrappedValue: auth)
    _odataService = StateObject(wrappedValue: ODataService(authManager: auth))
}
```

### 2. Query Entities (READ)

#### Basic Query
```swift
// Define your entity model
struct Territory: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "Name"
        case description = "Description"
        case createdAt = "CreatedAt"
    }
}

// Query all territories
let response = try await odataService.query(
    entitySet: "Territories"
) as ODataResponse<Territory>

let territories = response.value
let totalCount = response.count
```

#### Query with Filter
```swift
// Get territories where Name contains 'North'
let response = try await odataService.query(
    entitySet: "Territories",
    filter: "contains(Name, 'North')"
) as ODataResponse<Territory>
```

#### Query with Multiple Options
```swift
// Complex query with multiple OData options
let response = try await odataService.query(
    entitySet: "Territories",
    filter: "Status eq 'Active'",
    select: ["ID", "Name", "Description"],
    expand: ["Districts", "Assignments"],
    orderBy: "Name asc",
    top: 20,
    skip: 0
) as ODataResponse<Territory>
```

### 3. Create Entity (CREATE)

```swift
struct NewTerritory: Codable {
    let name: String
    let description: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case description = "Description"
        case status = "Status"
    }
}

let newTerritory = NewTerritory(
    name: "New District",
    description: "A new territory",
    status: "Active"
)

try await odataService.create(
    entitySet: "Territories",
    entity: newTerritory
)
```

### 4. Update Entity (UPDATE)

```swift
struct TerritoryUpdate: Codable {
    let name: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case description = "Description"
    }
}

let update = TerritoryUpdate(
    name: "Updated Name",
    description: "Updated description"
)

try await odataService.update(
    entitySet: "Territories",
    key: "'territory-id-123'",  // Note: String keys need single quotes
    entity: update
)
```

### 5. Delete Entity (DELETE)

```swift
try await odataService.delete(
    entitySet: "Territories",
    key: "'territory-id-123'"
)
```

## OData Filter Examples

### String Operations
```swift
// Contains
filter: "contains(Name, 'North')"

// Starts with
filter: "startswith(Name, 'District')"

// Ends with
filter: "endswith(Name, 'Region')"

// Equals
filter: "Name eq 'District A'"
```

### Comparison Operators
```swift
// Equal
filter: "Status eq 'Active'"

// Not equal
filter: "Status ne 'Inactive'"

// Greater than
filter: "CreatedDate gt 2024-01-01T00:00:00Z"

// Less than or equal
filter: "Priority le 5"
```

### Logical Operators
```swift
// AND
filter: "Status eq 'Active' and Type eq 'Personal'"

// OR
filter: "Status eq 'Active' or Status eq 'Pending'"

// NOT
filter: "not (Status eq 'Deleted')"
```

### Complex Filters
```swift
filter: "(Status eq 'Active' or Status eq 'Pending') and contains(Name, 'North')"
```

## Complete Example: Territory Manager

```swift
@MainActor
class TerritoryManager: ObservableObject {
    @Published var territories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let odataService: ODataService
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    func loadTerritories(filter: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: ODataResponse<Territory> = try await odataService.query(
                entitySet: "Territories",
                filter: filter,
                orderBy: "Name asc"
            )
            
            territories = response.value
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createTerritory(name: String, description: String) async throws {
        let newTerritory = NewTerritory(
            name: name,
            description: description,
            status: "Active"
        )
        
        try await odataService.create(
            entitySet: "Territories",
            entity: newTerritory
        )
        
        // Reload territories
        await loadTerritories()
    }
}
```

## Error Handling

```swift
do {
    let response = try await odataService.query(
        entitySet: "Territories"
    ) as ODataResponse<Territory>
    
    // Success
} catch ODataError.unauthorized {
    // User needs to log in again
    print("Please log in again")
} catch ODataError.requestFailed(let statusCode) {
    // Handle specific HTTP errors
    print("Request failed: \(statusCode)")
} catch {
    // Handle other errors
    print("Error: \(error.localizedDescription)")
}
```

## Key Naming Conventions

OData V4 typically uses PascalCase for property names, while Swift uses camelCase. Use `CodingKeys` to map:

```swift
struct Territory: Codable {
    let id: String
    let territoryName: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case territoryName = "TerritoryName"
        case isActive = "IsActive"
    }
}
```

## Pagination Example

```swift
func loadPage(pageNumber: Int, pageSize: Int = 20) async {
    let skip = pageNumber * pageSize
    
    let response: ODataResponse<Territory> = try await odataService.query(
        entitySet: "Territories",
        top: pageSize,
        skip: skip
    )
    
    territories = response.value
    totalCount = response.count ?? 0
    totalPages = Int(ceil(Double(totalCount) / Double(pageSize)))
}
```

## Date Handling

OData dates are typically in ISO 8601 format. Configure your JSONDecoder:

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

// Or custom format
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
decoder.dateDecodingStrategy = .formatted(formatter)
```

## Tips

1. **Always use proper OData key syntax**
   - String keys: `'value'` (with single quotes)
   - Integer keys: `123` (no quotes)
   - GUID keys: `guid'12345678-1234-1234-1234-123456789012'`

2. **URL encoding is automatic** - Don't manually encode query parameters

3. **Use $count=true** - Already included by default to get total count

4. **Authentication** - JWT token is automatically added to all requests

5. **Error handling** - Always handle OData errors appropriately
