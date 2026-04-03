import SwiftUI
import Combine

/// Unified detail view that replaces both TerritoryDetailView and GroupTerritoryDetailView.
/// `showTypePicker` controls whether the Personal/Public segmented picker is shown.
struct TerritoryAssignmentDetailView: View {
    let assignmentId: String
    let entitySet: String
    let showTypePicker: Bool
    let navigationTitle: String
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var detailManager: TerritoryAssignmentDetailManager
    @State private var selectedType: String
    @State private var isUpdatingType = false
    @State private var showScreenshotModal = false
    private let initialAssignment: TerritoryAssignment
    
    init(assignment: TerritoryAssignment, authManager: AuthManager, entitySet: String, showTypePicker: Bool = true, navigationTitle: String = "Territory Details") {
        self.assignmentId = assignment.id
        self.entitySet = entitySet
        self.showTypePicker = showTypePicker
        self.navigationTitle = navigationTitle
        self.initialAssignment = assignment
        _selectedType = State(initialValue: assignment.type ?? "Personal")
        let odataService = ODataService(authManager: authManager)
        _detailManager = StateObject(wrappedValue: TerritoryAssignmentDetailManager(odataService: odataService, entitySet: entitySet))
    }
    
    private var assignment: TerritoryAssignment {
        detailManager.assignment ?? initialAssignment
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    Text(assignment.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if showTypePicker {
                        Picker("Type", selection: $selectedType) {
                            Text("Personal").tag("Personal")
                            Text("Public").tag("Public")
                        }
                        .pickerStyle(.segmented)
                        .disabled(isUpdatingType)
                        .onChange(of: selectedType) { oldValue, newValue in
                            guard oldValue != newValue else { return }
                            isUpdatingType = true
                            Task {
                                do {
                                    try await detailManager.updateType(id: assignmentId, newType: newValue)
                                } catch {
                                    selectedType = oldValue
                                }
                                isUpdatingType = false
                            }
                        }
                    }
                    
                    if let link = assignment.link, let url = URL(string: link) {
                        if isImageURL(link) {
                            Button {
                                showScreenshotModal = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("View Screenshot")
                                }
                            }
                        } else {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Open Link")
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Overview Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overview")
                        .font(.headline)
                    
                    if let total = assignment.totalTerritoryCount {
                        StatRow(label: "Total Territories", value: "\(total)", icon: "map")
                    }
                    if let inProgress = assignment.inProgressTerritoryCount {
                        StatRow(label: "In Progress", value: "\(inProgress)", icon: "clock")
                    }
                    if let available = assignment.availableTerritoryCount {
                        StatRow(label: "Available", value: "\(available)", icon: "checkmark.circle")
                    }
                    
                    if assignment.startedDate != nil || assignment.finishedDate != nil {
                        Divider()
                    }
                    
                    if let started = assignment.startedDate {
                        StatRow(label: "Started", value: formatISODateToDDMMYYYY(started), icon: "calendar")
                    }
                    if let finished = assignment.finishedDate {
                        StatRow(label: "Finished", value: formatISODateToDDMMYYYY(finished), icon: "checkmark.circle")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Part Assignments Table
                if let partAssignments = assignment.toPartAssignments, !partAssignments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Part Assignments (\(partAssignments.count))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Table Rows
                        ForEach(partAssignments) { part in
                            NavigationLink(destination: PartAssignmentDetailView(
                                partAssignmentId: part.id,
                                authManager: authManager
                            )) {
                                VStack(spacing: 0) {
                                    // Map preview
                                    PartAssignmentMapPreview(
                                        partCoordinates: part.coordinates,
                                        boundaryCoordinates: part.toBoundaryPart?.coordinates
                                    )
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    
                                    // Row info
                                    HStack(spacing: 12) {
                                        // Status indicator
                                        Circle()
                                            .fill(part.isDone == true ? Color.gray : (part.inWorkBy?.isEmpty ?? true) ? Color.green : Color.orange)
                                            .frame(width: 8, height: 8)
                                        
                                        // Name
                                        Text(part.name ?? "Part \(part.id)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        // Assigned To
                                        if let workers = part.inWorkBy, !workers.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "person.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(workers.compactMap(\.name).prefix(2).joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                if workers.count > 2 {
                                                    Text("+\(workers.count - 2)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        } else {
                                            Text("Unassigned")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }
                                .background(Color(uiColor: .systemBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if part.id != partAssignments.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await detailManager.loadAssignment(id: assignmentId)
        }
        .task {
            await detailManager.loadAssignment(id: assignmentId)
            if let type = detailManager.assignment?.type {
                selectedType = type
            }
        }
        .sheet(isPresented: $showScreenshotModal) {
            if let link = assignment.link, let url = URL(string: link) {
                ScreenshotModalView(imageURL: url)
            }
        }
    }
}
