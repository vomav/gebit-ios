import SwiftUI
import Combine
import MapKit
import PhotosUI

struct PartAssignmentDetailView: View {
    let partAssignmentId: String
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager: PartAssignmentManager
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showAssignSheet = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var workerToRemove: WorkerDetail?
    @State private var selectedTab = 0
    @State private var showScreenshotModal = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploading = false
    
    init(partAssignmentId: String, authManager: AuthManager) {
        self.partAssignmentId = partAssignmentId
        let odataService = ODataService(authManager: authManager)
        _manager = StateObject(wrappedValue: PartAssignmentManager(odataService: odataService))
    }
    
    var body: some View {
        Group {
            if manager.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            } else if let errorMessage = manager.errorMessage {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Error Loading Part Assignment")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task {
                                await manager.refresh(id: partAssignmentId)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            } else if let part = manager.partAssignment {
                VStack(spacing: 0) {
                    // Icon Tab Bar
                    HStack(spacing: 0) {
                        IconTabButton(title: "Details", icon: "doc.text.magnifyingglass", tag: 0, selectedTab: $selectedTab)
                        IconTabButton(title: "Map", icon: "mappin.circle", tag: 1, selectedTab: $selectedTab)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        detailsTabContent(part: part)
                            .tag(0)
                        
                        mapTabContent(part: part)
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "doc",
                    description: Text("Part assignment data could not be loaded.")
                )
            }
        }
        .navigationTitle("Part Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await manager.refresh(id: partAssignmentId)
        }
        .task {
            await manager.loadPartAssignment(id: partAssignmentId)
        }
        .sheet(isPresented: $showAssignSheet) {
            if let part = manager.partAssignment {
                UserSelectionSheet(
                    allowedUsers: part.toAllowedUsers ?? [],
                    onSelect: { user in
                        showAssignSheet = false
                        Task {
                            await assignToUser(userId: user.id)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showScreenshotModal) {
            if let part = manager.partAssignment,
               let imageUrl = part.workedPartImageUrl,
               let url = URL(string: imageUrl) {
                ScreenshotModalView(imageURL: url)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadSelectedPhoto(item: newItem)
                selectedPhotoItem = nil
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Remove Worker", isPresented: Binding(
            get: { workerToRemove != nil },
            set: { if !$0 { workerToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                workerToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let worker = workerToRemove {
                    workerToRemove = nil
                    Task {
                        await removeWorker(inWorkById: worker.id)
                    }
                }
            }
        } message: {
            if let worker = workerToRemove {
                Text("Are you sure you want to remove \(worker.displayName) from this part assignment?")
            }
        }
    }
    
    // MARK: - Details Tab
    
    @ViewBuilder
    private func detailsTabContent(part: PartAssignmentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Assignment Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Assignment")
                        .font(.headline)
                    
                    // Assign row
                    HStack(alignment: .top) {
                        Text("Assign:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        VStack(spacing: 8) {
                            // Assign to Me
                            Button(action: {
                                Task { await assignToMe() }
                            }) {
                                HStack {
                                    Image(systemName: "person.fill")
                                    Text("Assign to Me")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isProcessing)
                            
                            // Assign to User
                            if let allowedUsers = part.toAllowedUsers, !allowedUsers.isEmpty {
                                Button(action: {
                                    showAssignSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                        Text("Assign to User")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.purple)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(isProcessing)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Assigned to row
                    HStack(alignment: .top) {
                        Text("Assigned to:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        if let workers = part.inWorkBy, !workers.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(workers) { worker in
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundStyle(.blue)
                                        
                                        Text(worker.displayName)
                                            .font(.subheadline)
                                        
                                        if let username = worker.username {
                                            Text("@\(username)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(role: .destructive) {
                                            workerToRemove = worker
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isProcessing)
                                    }
                                }
                            }
                        } else {
                            Text("Unassigned")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // Progress Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Progress")
                        .font(.headline)
                    
                    // Done row
                    HStack {
                        Text("Done:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        Button(action: {
                            Task { await toggleDoneStatus(part: part) }
                        }) {
                            Image(systemName: part.isDone == true ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(part.isDone == true ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Count row
                    HStack {
                        Text("Count:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        HStack(spacing: 0) {
                            Button {
                                let current = part.count ?? 0
                                guard current > 0 else { return }
                                Task { await updateCount(newCount: current - 1) }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.body)
                                    .frame(width: 44, height: 36)
                                    .foregroundStyle(part.count ?? 0 > 0 ? .primary : .tertiary)
                            }
                            .disabled((part.count ?? 0) <= 0)
                            
                            Text("\(part.count ?? 0)")
                                .font(.body)
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .frame(minWidth: 44)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                let current = part.count ?? 0
                                Task { await updateCount(newCount: current + 1) }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.body)
                                    .frame(width: 44, height: 36)
                            }
                        }
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                        )
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Screenshots row
                    HStack {
                        Text("Screenshots:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        if let imageUrl = part.workedPartImageUrl, URL(string: imageUrl) != nil {
                            Button {
                                showScreenshotModal = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo")
                                    Text("View")
                                }
                                .font(.subheadline)
                            }
                        } else {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            HStack(spacing: 4) {
                                if isUploading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                Text(isUploading ? String(localized: "Uploading...") : String(localized: "Upload"))
                            }
                            .font(.subheadline)
                        }
                        .disabled(isProcessing || isUploading)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                
                // External Resources Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("External Resources")
                        .font(.headline)
                    
                    HStack {
                        Text("forebears.io:")
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        Link("Link", destination: URL(string: "https://forebears.io")!)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    // MARK: - Map Tab
    
    @ViewBuilder
    private func mapTabContent(part: PartAssignmentDetail) -> some View {
        if hasCoordinates(part: part) {
            VStack(spacing: 0) {
                Map(position: $mapPosition) {
                    if let coords = parseCoordinateString(part.coordinates), !coords.isEmpty {
                        MapPolygon(coordinates: coords)
                            .foregroundStyle(.blue.opacity(0.2))
                            .stroke(.blue, lineWidth: 2.5)
                    }
                    
                    if let boundaryCoords = parseCoordinateString(part.toBoundaryPart?.coordinates), !boundaryCoords.isEmpty {
                        MapPolygon(coordinates: boundaryCoords)
                            .foregroundStyle(.red.opacity(0.15))
                            .stroke(.red, lineWidth: 2.5)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .task {
                    let allCoords = getAllCoordinates(part: part)
                    if !allCoords.isEmpty {
                        mapPosition = .region(calculateMapRegion(for: allCoords))
                    }
                }
                
                // Legend
                HStack(spacing: 20) {
                    if parseCoordinateString(part.coordinates) != nil {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(.blue.opacity(0.2))
                                .stroke(.blue, lineWidth: 2)
                                .frame(width: 24, height: 16)
                            Text("Part Assignment")
                                .font(.caption)
                        }
                    }
                    
                    if parseCoordinateString(part.toBoundaryPart?.coordinates) != nil {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(.red.opacity(0.15))
                                .stroke(.red, lineWidth: 2)
                                .frame(width: 24, height: 16)
                            Text("Boundary")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
            }
        } else {
            ContentUnavailableView(
                "No Map Data",
                systemImage: "map",
                description: Text("No coordinates available for this part assignment.")
            )
        }
    }
    
    // MARK: - Action Methods
    
    private func toggleDoneStatus(part: PartAssignmentDetail) async {
        do {
            try await manager.toggleDone(id: partAssignmentId, currentStatus: part.isDone ?? false)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func assignToMe() async {
        isProcessing = true
        do {
            try await manager.assignToMe(id: partAssignmentId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    private func assignToUser(userId: String) async {
        isProcessing = true
        do {
            try await manager.assignToUser(id: partAssignmentId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    private func updateCount(newCount: Int) async {
        do {
            try await manager.updateCount(id: partAssignmentId, newCount: newCount)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func removeWorker(inWorkById: String) async {
        isProcessing = true
        do {
            try await manager.removeWorker(partAssignmentId: partAssignmentId, inWorkById: inWorkById)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    private func uploadSelectedPhoto(item: PhotosPickerItem) async {
        isUploading = true
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ODataError.invalidResponse
            }
            
            guard var uiImage = UIImage(data: data) else {
                throw ODataError.invalidResponse
            }
            
            // Downscale if the image is larger than 1280px on any side
            let maxDimension: CGFloat = 1280
            let originalSize = uiImage.size
            if originalSize.width > maxDimension || originalSize.height > maxDimension {
                let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
                let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                uiImage = renderer.image { _ in
                    uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
            }
            
            // Target ~700 KB so the base64 payload stays under 1 MB
            let maxSize = 700_000
            var quality: CGFloat = 0.7
            guard var jpegData = uiImage.jpegData(compressionQuality: quality) else {
                throw ODataError.invalidResponse
            }
            while jpegData.count > maxSize && quality > 0.1 {
                quality -= 0.1
                if let reduced = uiImage.jpegData(compressionQuality: quality) {
                    jpegData = reduced
                }
            }
            
            try await manager.uploadImage(id: partAssignmentId, imageData: jpegData)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUploading = false
    }
    
    // MARK: - Helper Methods
    
    private func hasCoordinates(part: PartAssignmentDetail) -> Bool {
        let hasPart = part.coordinates != nil && !part.coordinates!.isEmpty
        let hasBoundary = part.toBoundaryPart?.coordinates != nil && !part.toBoundaryPart!.coordinates!.isEmpty
        return hasPart || hasBoundary
    }
    
    private func getAllCoordinates(part: PartAssignmentDetail) -> [CLLocationCoordinate2D] {
        (parseCoordinateString(part.coordinates) ?? []) +
        (parseCoordinateString(part.toBoundaryPart?.coordinates) ?? [])
    }
}
