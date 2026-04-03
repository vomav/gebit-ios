import SwiftUI
import Combine

/// Unified manager that replaces both TerritoryManager and GroupTerritoryManager.
/// The only difference is the `entitySet` parameter.
@MainActor
class TerritoryAssignmentManager: ObservableObject {
    @Published var assignments: [TerritoryAssignment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalCount: Int = 0
    
    private let odataService: ODataService
    private let entitySet: String
    private var currentPage = 0
    
    init(odataService: ODataService, entitySet: String) {
        self.odataService = odataService
        self.entitySet = entitySet
    }
    
    func loadAssignments(page: Int = 0) async {
        isLoading = true
        errorMessage = nil
        currentPage = page
        
        do {
            let response: ODataResponse<TerritoryAssignment> = try await odataService.query(
                entitySet: entitySet,
                select: ["ID", "availableTerritoryCount", "finishedDate", "inProgressTerritoryCount", "link", "name", "startedDate", "totalTerritoryCount", "type"],
                expand: ["toPartAssignments($expand=inWorkBy,toBoundaryPart($select=ID,coordinates);$select=ID,name,coordinates,isBoundaries,isDone;$orderby=name)"],
                top: AppConstants.pageSize,
                skip: page * AppConstants.pageSize
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
        await loadAssignments(page: currentPage + 1)
    }
    
    func refresh() async {
        await loadAssignments(page: 0)
    }
}
