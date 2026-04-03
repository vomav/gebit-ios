import SwiftUI
import Combine
import MapKit

struct TerritoryManageDetailView: View {
    let territoryId: String
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var detailManager: TerritoryManageDetailManager
    @State private var selectedTab = 0
    @State private var showAssignSheet = false
    @State private var showWithdrawConfirmation = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var actionErrorMessage = ""
    
    init(territory: Territory, authManager: AuthManager) {
        self.territoryId = territory.id
        let odataService = ODataService(authManager: authManager)
        _detailManager = StateObject(wrappedValue: TerritoryManageDetailManager(odataService: odataService))
    }
    
    var body: some View {
        Group {
            if detailManager.isLoading && detailManager.territory == nil {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let errorMessage = detailManager.errorMessage, detailManager.territory == nil {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Error Loading Territory")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task {
                                await detailManager.loadTerritory(id: territoryId)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let territory = detailManager.territory {
                VStack(spacing: 0) {
                    // Icon Tab Bar
                    HStack(spacing: 0) {
                        IconTabButton(title: "General Info", icon: "info.circle", tag: 0, selectedTab: $selectedTab)
                        IconTabButton(title: "Map", icon: "map", tag: 1, selectedTab: $selectedTab)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        generalInfoTab(territory: territory)
                            .tag(0)
                        
                        mapTab(territory: territory)
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "doc",
                    description: Text("Territory data could not be loaded.")
                )
            }
        }
        .navigationTitle(detailManager.territory?.name ?? String(localized: "Territory"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await detailManager.refresh(id: territoryId)
        }
        .task {
            await detailManager.loadTerritory(id: territoryId)
        }
        .sheet(isPresented: $showAssignSheet) {
            if let territory = detailManager.territory {
                UserSelectionSheet(
                    allowedUsers: territory.toAllowedUsers ?? [],
                    onSelect: { user in
                        showAssignSheet = false
                        Task {
                            await assignToUser(userId: user.id)
                        }
                    }
                )
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionErrorMessage)
        }
        .alert("Withdraw Territory", isPresented: $showWithdrawConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Withdraw", role: .destructive) {
                Task {
                    await withdrawFromUser()
                }
            }
        } message: {
            Text("Are you sure you want to withdraw this territory from the current user?")
        }
    }
    
    // MARK: - Actions
    
    private func assignToUser(userId: String) async {
        isProcessing = true
        do {
            try await detailManager.assignToUser(territoryId: territoryId, userId: userId)
        } catch {
            actionErrorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    private func withdrawFromUser() async {
        isProcessing = true
        do {
            try await detailManager.withdrawFromUser(territoryId: territoryId)
        } catch {
            actionErrorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    // MARK: - General Info Tab
    
    private func generalInfoTab(territory: TerritoryDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    Text(territory.name ?? String(localized: "Unnamed"))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if territory.isReady == true {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ready")
                                .fontWeight(.medium)
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text("Not Ready")
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    if let link = territory.link, let url = URL(string: link) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "link")
                                Text("Open Link")
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Details Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                    
                    StatRow(label: "Assigned To", value: territory.assignedToDisplayName, icon: "person")
                    StatRow(label: "Last Worked", value: territory.formattedLastTimeWorked, icon: "clock")
                    
                    if let total = territory.totalCount {
                        StatRow(label: "Total Parts", value: "\(total)", icon: "square.stack.3d.up")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Actions Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.headline)
                    
                    if territory.assignedToName == nil && territory.assignedUnregisteredUser == nil {
                        Button {
                            showAssignSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Assign to User")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Assign this territory to a registered user")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if isProcessing {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(isProcessing)
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button {
                            showWithdrawConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.minus")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Withdraw from User")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.red)
                                    Text("Remove the current user assignment")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if isProcessing {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isProcessing)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Parts List
                if let parts = territory.toParts, !parts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Parts (\(parts.count))")
                            .font(.headline)
                        
                        ForEach(parts) { part in
                            HStack {
                                Circle()
                                    .fill(part.isBoundaries == true ? Color.red.opacity(0.7) : Color.blue.opacity(0.7))
                                    .frame(width: 8, height: 8)
                                
                                Text(part.name ?? "Part \(part.id)")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                if let count = part.count {
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color(uiColor: .tertiarySystemBackground))
                                        .cornerRadius(4)
                                }
                                
                                if part.isBoundaries == true {
                                    Text("Boundary")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.red.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            if part.id != parts.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helpers
    
    private func polygonCenter(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let latSum = coords.reduce(0.0) { $0 + $1.latitude }
        let lonSum = coords.reduce(0.0) { $0 + $1.longitude }
        let count = Double(coords.count)
        return CLLocationCoordinate2D(latitude: latSum / count, longitude: lonSum / count)
    }
    
    // MARK: - Map Tab
    
    @ViewBuilder
    private func mapTab(territory: TerritoryDetail) -> some View {
        let boundaryCoords = parseCoordinateString(territory.toBoundaryPart?.coordinates)
        let partPolygons: [(id: String, name: String?, coords: [CLLocationCoordinate2D], isBoundary: Bool)] = (territory.toParts ?? []).compactMap { part in
            guard let coords = parseCoordinateString(part.coordinates), !coords.isEmpty else { return nil }
            return (id: part.id, name: part.name, coords: coords, isBoundary: part.isBoundaries == true)
        }
        
        let allCoords = (boundaryCoords ?? []) + partPolygons.flatMap { $0.coords }
        
        if allCoords.isEmpty {
            ContentUnavailableView(
                "No Map Data",
                systemImage: "map",
                description: Text("No coordinates available for this territory.")
            )
        } else {
            let region = calculateMapRegion(for: allCoords)
            
            Map(initialPosition: .region(region)) {
                // Boundary polygon
                if let coords = boundaryCoords, !coords.isEmpty {
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(.red.opacity(0.1))
                        .stroke(.red, lineWidth: 2)
                }
                
                // Part polygons
                ForEach(partPolygons, id: \.id) { part in
                    MapPolygon(coordinates: part.coords)
                        .foregroundStyle(part.isBoundary ? .red.opacity(0.15) : .blue.opacity(0.2))
                        .stroke(part.isBoundary ? .red : .blue, lineWidth: 1.5)
                    
                    if let name = part.name {
                        let center = polygonCenter(part.coords)
                        Annotation("", coordinate: center) {
                            Text(name)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .mapStyle(.standard)
        }
    }
}
