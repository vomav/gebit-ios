# Territory Assignment Screen Implementation

## Overview
A complete implementation for loading and displaying territory assignments from the OData V4 service.

## API Endpoint
```
GET https://my-territory.app/odata/v4/srv.searching/TerritoryAssignments
```

### Query Parameters
- `$expand=toPartAssignments($expand=inWorkBy;$select=isBoundaries,isDone)`
- `$select=ID,availableTerritoryCount,finishedDate,inProgressTerritoryCount,link,name,startedDate,totalTerritoryCount,type`
- `$skip=0`
- `$top=20`

## Features Implemented

### 1. Data Models

#### TerritoryAssignment
```swift
struct TerritoryAssignment: Codable, Identifiable {
    let id: String                      // ID
    let name: String                    // name
    let type: String?                   // type
    let link: String?                   // link
    let startedDate: String?            // startedDate
    let finishedDate: String?           // finishedDate
    let availableTerritoryCount: Int?   // availableTerritoryCount
    let inProgressTerritoryCount: Int?  // inProgressTerritoryCount
    let totalTerritoryCount: Int?       // totalTerritoryCount
    let toPartAssignments: [PartAssignment]?
}
```

#### PartAssignment
```swift
struct PartAssignment: Codable, Identifiable {
    let isBoundaries: Bool?
    let isDone: Bool?
    let inWorkBy: InWorkBy?
}
```

#### InWorkBy
```swift
struct InWorkBy: Codable {
    let name: String?
    let email: String?
}
```

### 2. TerritoryManager

A dedicated manager class that handles:
- Loading territory assignments from OData
- Pagination (20 items per page)
- Error handling
- Loading states
- Pull-to-refresh

```swift
@MainActor
class TerritoryManager: ObservableObject {
    @Published var assignments: [TerritoryAssignment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalCount: Int = 0
    
    func loadMyTerritories(page: Int = 0) async
    func loadNextPage() async
    func refresh() async
}
```

### 3. UI Components

#### TerritoriesView
Main list view showing all territory assignments with:
- Pull-to-refresh support
- Loading indicators
- Error handling UI
- Empty state
- Pagination ("Load More" button)
- Automatic initial data load

#### TerritoryAssignmentRow
Custom row component displaying:
- Territory name and type
- Completion status icon
- Statistics badges:
  - Total territories (blue)
  - In Progress (orange)
  - Available (green)
- Start date
- Preview of part assignments (first 3)
- Worker names and completion status

#### TerritoryDetailView
Detailed view showing:
- Full territory information
- All statistics in organized cards
- Complete timeline (started/finished dates)
- Full list of part assignments with:
  - Worker name and email
  - Completion status
  - Boundaries indicator

#### StatBadge
Reusable component for displaying statistics with:
- Icon
- Value
- Label
- Color-coded background

## User Flow

1. **Login** → User authenticates
2. **Home Screen** → User sees two options
3. **Tap "My Territories"** → Navigate to TerritoriesView
4. **Auto-load Data** → Fetches first 20 assignments from OData
5. **View List** → See all assignments with statistics
6. **Pull to Refresh** → Reload data from server
7. **Tap Assignment** → Navigate to detailed view
8. **Load More** → Tap to load next 20 items (pagination)

## Visual Features

### List View
- Clean card-based design
- Color-coded statistics
- Status indicators (✓ for completed)
- Preview of workers
- Date information

### Detail View
- Organized into sections:
  - Header (name, type, link)
  - Statistics card
  - Timeline card
  - Part Assignments list
- All information clearly labeled
- Scrollable for long content

## Error Handling

The implementation handles:
- Network errors
- Authentication errors (unauthorized)
- Server errors (4xx, 5xx)
- Empty states
- Loading states

### Error UI
```
⚠️
Error Loading Territories
[Error message]
[Try Again Button]
```

## Pagination

- Initial load: 20 items
- "Load More" button appears when there are more items
- Shows current count vs. total count
- Disabled while loading
- Incremental loading (doesn't replace existing data)

## Refresh Mechanism

Two ways to refresh:
1. **Pull-to-Refresh** - Swipe down on the list
2. **Try Again Button** - On error screen

Both reset pagination and load from page 0.

## Loading States

### Initial Load
- Shows centered ProgressView

### Pagination Load
- Shows floating ProgressView at bottom
- Doesn't block interaction
- Uses `.regularMaterial` background

### Pull-to-Refresh
- Native iOS pull-to-refresh indicator

## Date Formatting

Dates are automatically formatted from ISO 8601 to readable format:
- Input: `2026-03-08T10:30:00Z`
- Output: `Mar 8, 2026`

## Authentication Integration

- Automatically uses JWT token from AuthManager
- All requests include `Authorization: Bearer <token>`
- Handles unauthorized errors by showing error message
- User can logout and login again if token expires

## Testing the Implementation

1. **Login with real credentials**
2. **Tap "My Territories"**
3. **Verify the following:**
   - Data loads from OData endpoint
   - List shows territory assignments
   - Statistics are displayed correctly
   - Tap on an item opens detail view
   - Pull to refresh works
   - "Load More" loads next page
   - Error handling works (test with airplane mode)

## Sample Data Display

For a territory assignment from the API:
```json
{
  "ID": "abc123",
  "name": "North District Assignment",
  "type": "Personal",
  "totalTerritoryCount": 15,
  "inProgressTerritoryCount": 5,
  "availableTerritoryCount": 10,
  "startedDate": "2026-03-01T00:00:00Z",
  "toPartAssignments": [
    {
      "isBoundaries": true,
      "isDone": false,
      "inWorkBy": {
        "name": "John Doe",
        "email": "john@email.com"
      }
    }
  ]
}
```

Will display as:

```
North District Assignment
Personal

[15] Total  [5] In Progress  [10] Available

📅 Started: Mar 1, 2026

Assignments
✓ John Doe          🗺️
```

## Next Steps

To extend this implementation:

1. **Add filtering** - Filter by status, date, type
2. **Add search** - Search by territory name
3. **Add sorting** - Sort by date, name, status
4. **Map integration** - Show territories on map
5. **Offline support** - Cache data locally
6. **Push notifications** - Alert on new assignments

## Code Location

All code is in `ContentView.swift`:
- Lines ~32-81: Data Models
- Lines ~351-401: TerritoryManager
- Lines ~450-550: TerritoriesView
- Lines ~551-650: TerritoryAssignmentRow
- Lines ~651-750: TerritoryDetailView
