import SwiftUI
import Combine

struct ManageTerritoriesView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager: ManageTerritoryManager
    @State private var searchText = ""
    @State private var assignmentFilter: TerritoryAssignmentFilter = .all
    @State private var searchTask: Task<Void, Never>?
    
    init(authManager: AuthManager) {
        let odataService = ODataService(authManager: authManager)
        _manager = StateObject(wrappedValue: ManageTerritoryManager(odataService: odataService))
    }
    
    var body: some View {
        Group {
            if manager.isLoading && manager.territories.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let errorMessage = manager.errorMessage, manager.territories.isEmpty {
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
                                await manager.loadTerritories(searchText: searchText, assignmentFilter: assignmentFilter)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if manager.territories.isEmpty {
                ContentUnavailableView(
                    "No Territories",
                    systemImage: "map",
                    description: Text("No territories match your filters.")
                )
            } else {
                List {
                    ForEach(manager.territories) { territory in
                        NavigationLink(destination: TerritoryManageDetailView(territory: territory, authManager: authManager)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(territory.name ?? String(localized: "Unnamed"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(territory.assignedToDisplayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(territory.formattedLastTimeWorked)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if territory.isReady == true {
                                    Text("Ready")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.12))
                                        .cornerRadius(6)
                                } else {
                                    Text("Not Ready")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.12))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if manager.territories.count < manager.totalCount {
                        HStack {
                            Spacer()
                            if manager.isLoading {
                                ProgressView()
                            } else {
                                Button("Load More") {
                                    Task {
                                        await manager.loadNextPage()
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Territories")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search by name or assigned person")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $assignmentFilter) {
                        ForEach(TerritoryAssignmentFilter.allCases, id: \.self) { filter in
                            Text(filter.localizedName).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: assignmentFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .onChange(of: searchText) {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await manager.loadTerritories(searchText: searchText, assignmentFilter: assignmentFilter)
            }
        }
        .onChange(of: assignmentFilter) {
            Task {
                await manager.loadTerritories(searchText: searchText, assignmentFilter: assignmentFilter)
            }
        }
        .refreshable {
            await manager.loadTerritories(searchText: searchText, assignmentFilter: assignmentFilter)
        }
        .task {
            await manager.loadTerritories()
        }
    }
}
