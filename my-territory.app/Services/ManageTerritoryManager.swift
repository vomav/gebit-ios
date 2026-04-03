import SwiftUI
import Combine

@MainActor
class ManageTerritoryManager: ObservableObject {
    @Published var territories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalCount: Int = 0
    
    private let odataService: ODataService
    private var currentPage = 0
    private var currentSearchText = ""
    private var currentFilter: TerritoryAssignmentFilter = .all
    
    init(odataService: ODataService) {
        self.odataService = odataService
    }
    
    private func buildFilter(searchText: String, assignmentFilter: TerritoryAssignmentFilter) -> String? {
        var filters: [String] = []
        
        if !searchText.isEmpty {
            let escaped = searchText.replacingOccurrences(of: "'", with: "''")
            filters.append("(contains(tolower(name),tolower('\(escaped)')) or contains(tolower(assignedToName),tolower('\(escaped)')) or contains(tolower(assignedToSurname),tolower('\(escaped)')) or contains(tolower(assignedUnregisteredUser),tolower('\(escaped)')))")
        }
        
        switch assignmentFilter {
        case .assigned:
            filters.append("(assignedToName ne null or assignedUnregisteredUser ne null)")
        case .available:
            filters.append("assignedToName eq null and assignedUnregisteredUser eq null")
        case .all:
            break
        }
        
        return filters.isEmpty ? nil : filters.joined(separator: " and ")
    }
    
    func loadTerritories(page: Int = 0, searchText: String = "", assignmentFilter: TerritoryAssignmentFilter = .all) async {
        isLoading = true
        errorMessage = nil
        currentPage = page
        currentSearchText = searchText
        currentFilter = assignmentFilter
        
        do {
            let response: ODataResponse<Territory> = try await odataService.query(
                entitySet: "Territories",
                filter: buildFilter(searchText: searchText, assignmentFilter: assignmentFilter),
                select: ["ID", "assignedToName", "assignedToSurname", "assignedUnregisteredUser", "isReady", "lastTimeWorked", "link", "name", "siteName", "totalCount"],
                top: AppConstants.pageSize,
                skip: page * AppConstants.pageSize
            )
            
            if page == 0 {
                territories = response.value
            } else {
                territories.append(contentsOf: response.value)
            }
            totalCount = response.count ?? 0
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading territories: \(error)")
        }
        
        isLoading = false
    }
    
    func loadNextPage() async {
        guard !isLoading, territories.count < totalCount else { return }
        await loadTerritories(page: currentPage + 1, searchText: currentSearchText, assignmentFilter: currentFilter)
    }
    
    func refresh() async {
        await loadTerritories(page: 0, searchText: currentSearchText, assignmentFilter: currentFilter)
    }
}
