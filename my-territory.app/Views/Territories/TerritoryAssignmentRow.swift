import SwiftUI

struct TerritoryAssignmentRow: View {
    let assignment: TerritoryAssignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.name)
                        .font(.headline)
                    
                    if let type = assignment.type {
                        Text(type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if assignment.finishedDate != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            // Statistics
            HStack(spacing: 16) {
                if let total = assignment.totalTerritoryCount {
                    StatBadge(
                        icon: "map",
                        label: "Total",
                        value: "\(total)",
                        color: .blue
                    )
                }
                
                if let inProgress = assignment.inProgressTerritoryCount {
                    StatBadge(
                        icon: "clock",
                        label: "In Progress",
                        value: "\(inProgress)",
                        color: .orange
                    )
                }
                
                if let available = assignment.availableTerritoryCount {
                    StatBadge(
                        icon: "checkmark.circle",
                        label: "Available",
                        value: "\(available)",
                        color: .green
                    )
                }
            }
            
            // Dates
            if let startedDate = assignment.startedDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Started: \(formatISODateToDDMMYYYY(startedDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
