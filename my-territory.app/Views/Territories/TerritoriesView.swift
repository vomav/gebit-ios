import SwiftUI
import Combine

struct TerritoriesView: View {
    @EnvironmentObject var authManager: AuthManager
    let isGroupMode: Bool
    @StateObject private var manager: TerritoryAssignmentManager
    
    init(isGroupMode: Bool, authManager: AuthManager) {
        self.isGroupMode = isGroupMode
        let odataService = ODataService(authManager: authManager)
        let entitySet = isGroupMode ? "PublicTerritoryAssignments" : "TerritoryAssignments"
        _manager = StateObject(wrappedValue: TerritoryAssignmentManager(odataService: odataService, entitySet: entitySet))
    }
    
    var body: some View {
        Group {
            if manager.isLoading && manager.assignments.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let errorMessage = manager.errorMessage {
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
                                await manager.refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if manager.assignments.isEmpty {
                ContentUnavailableView(
                    "No Territories",
                    systemImage: "map",
                    description: Text("There are no territories assigned yet.")
                )
            } else {
                List {
                    ForEach(manager.assignments) { assignment in
                        NavigationLink(destination: TerritoryAssignmentDetailView(
                            assignment: assignment,
                            authManager: authManager,
                            entitySet: isGroupMode ? "PublicTerritoryAssignments" : "TerritoryAssignments",
                            showTypePicker: !isGroupMode,
                            navigationTitle: isGroupMode ? "Group Territory Details" : "Territory Details"
                        )) {
                            TerritoryAssignmentRow(assignment: assignment)
                        }
                    }
                    
                    // Load more button
                    if manager.assignments.count < manager.totalCount {
                        HStack {
                            Spacer()
                            Button("Load More") {
                                Task {
                                    await manager.loadNextPage()
                                }
                            }
                            .disabled(manager.isLoading)
                            Spacer()
                        }
                        .padding()
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(isGroupMode ? String(localized: "Group Territories") : String(localized: "My Territories"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await manager.refresh()
        }
        .task {
            await manager.loadAssignments()
        }
        .overlay {
            if manager.isLoading && !manager.assignments.isEmpty {
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
