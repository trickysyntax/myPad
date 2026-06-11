import SwiftUI
import MyPadKit

/// Project detail with segmented tabs: Rooms, Selections, Budget.
struct ProjectDetailView: View {
    let projectId: String

    @State private var project: ProjectDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = ProjectTab.rooms
    @State private var showEditProject = false
    @State private var showCaptureProject = false
    @State private var viewingCapture: SpaceCaptureSummary?
    @State private var showRemoveCaptureConfirm = false

    enum ProjectTab: String, CaseIterable {
        case rooms = "Rooms"
        case selections = "Selections"
        case budget = "Budget"
    }

    private let api = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("View", selection: $selectedTab) {
                ForEach(ProjectTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Tab content
            Group {
                if isLoading {
                    Spacer()
                    ProgressView("Loading project...")
                    Spacer()
                } else if let project {
                    switch selectedTab {
                    case .rooms:
                        roomsTab(project)
                    case .selections:
                        selectionsTab
                    case .budget:
                        BudgetView(projectId: project.id)
                    }
                } else if let error = errorMessage {
                    Spacer()
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: "Failed to Load",
                        message: error
                    )
                    Spacer()
                }
            }
        }
        .background(Color.studioSurface)
        .navigationTitle(project?.name ?? "Project")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCaptureProject = true
                    } label: {
                        Label(project?.spaceCapture == nil ? "Capture 3D Project" : "Recapture 3D Project", systemImage: "cube.transparent")
                    }

                    if project?.spaceCapture != nil {
                        Button(role: .destructive) {
                            showRemoveCaptureConfirm = true
                        } label: {
                            Label("Remove 3D Capture", systemImage: "trash")
                        }
                    }

                    Divider()

                    Button { showEditProject = true } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditProject) {
            if let project {
                EditProjectView(project: project) { updated in
                    self.project = updated
                    Task { await load() }
                }
            }
        }
        .sheet(isPresented: $showCaptureProject) {
            if let project {
                SpaceCaptureSheet(scope: .project(projectId: project.id, name: project.name)) { _ in
                    Task { await load() }
                }
            }
        }
        .sheet(item: $viewingCapture) { capture in
            SpaceCaptureViewer(capture: capture)
        }
        .confirmationDialog(
            "Remove this 3D capture?",
            isPresented: $showRemoveCaptureConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove 3D Capture", role: .destructive) {
                Task { await removeProjectCapture() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current project capture will be hidden. You can capture the project again from the menu.")
        }
    }

    // MARK: - Rooms Tab

    @ViewBuilder
    private func roomsTab(_ project: ProjectDetail) -> some View {
        if let rooms = project.rooms, !rooms.isEmpty {
            RoomGridView(
                projectId: project.id,
                rooms: rooms,
                projectCapture: project.spaceCapture,
                onOpenProjectCapture: { if let capture = project.spaceCapture { viewingCapture = capture } },
                onCaptureProject: { showCaptureProject = true },
                onRoomsChanged: { Task { await load() } }
            )
            .background(Color.studioSurface)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    SpaceCapturePreviewCard(
                        capture: project.spaceCapture,
                        title: "Project 3D Capture",
                        emptyTitle: "Capture the Project in 3D",
                        emptyMessage: "Scan the full project envelope with a LiDAR iPad to keep spatial context beside rooms and selections.",
                        onOpen: { if let capture = project.spaceCapture { viewingCapture = capture } },
                        onCapture: { showCaptureProject = true }
                    )

                    EmptyStateView(
                        systemImage: "square.split.bottomrightquarter",
                        title: "No Rooms",
                        message: "Add rooms to this project to start organizing selections."
                    )
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color.studioSurface)
        }
    }

    // MARK: - Selections Tab

    @State private var allSelections: [SelectionDetail] = []
    @State private var isLoadingSelections = false
    @State private var selectionFilter: String? = nil

    private var selectionsTab: some View {
        VStack(spacing: 0) {
            // Status filter pills
            SelectionStatusFilter(selected: $selectionFilter)
                .padding(.horizontal)
                .padding(.bottom, 4)

            if isLoadingSelections {
                Spacer()
                ProgressView("Loading selections...")
                Spacer()
            } else if filteredSelections.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: "checklist",
                    title: "No Selections",
                    message: "Add assets to rooms from the Rooms tab."
                )
                Spacer()
            } else {
                List {
                    // Group by room
                    ForEach(groupedByRoom, id: \.0) { roomName, selections in
                        Section(roomName) {
                            ForEach(selections) { selection in
                                NavigationLink {
                                    SelectionDetailView(
                                        selection: selection,
                                        projectId: projectId,
                                        roomId: selection.roomId ?? ""
                                    )
                                } label: {
                                    SelectionRowCompact(selection: selection)
                            .listRowBackground(Color.studioSurface)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.studioSurface)
                .listStyle(.insetGrouped)
            }
        }
        .task { await loadSelections() }
        .onChange(of: selectionFilter) { _, _ in
            Task { await loadSelections() }
        }
    }

    private var filteredSelections: [SelectionDetail] {
        guard let filter = selectionFilter else { return allSelections }
        return allSelections.filter { $0.status == filter }
    }

    private var groupedByRoom: [(String, [SelectionDetail])] {
        let grouped = Dictionary(grouping: filteredSelections) { $0.room?.name ?? "Unassigned" }
        return grouped.sorted { $0.key < $1.key }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            project = try await api.getProject(id: projectId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSelections() async {
        guard let rooms = project?.rooms else { return }
        isLoadingSelections = true
        defer { isLoadingSelections = false }

        await withTaskGroup(of: [SelectionDetail].self) { group in
            for room in rooms {
                group.addTask {
                    do {
                        return try await api.listSelections(
                            projectId: projectId,
                            roomId: room.id,
                            status: selectionFilter
                        )
                    } catch {
                        return []
                    }
                }
            }

            var collected: [SelectionDetail] = []
            for await selections in group {
                collected.append(contentsOf: selections)
            }
            allSelections = collected
        }
    }

    private func removeProjectCapture() async {
        do {
            _ = try await api.deleteProjectSpaceCapture(projectId: projectId)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Edit Project Sheet

struct EditProjectView: View {
    let project: ProjectDetail
    let onSaved: (ProjectDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var projectType: String
    @State private var notes: String
    @State private var coverPhotoUrl: String?
    @State private var rooms: [RoomRef]
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(project: ProjectDetail, onSaved: @escaping (ProjectDetail) -> Void) {
        self.project = project
        self.onSaved = onSaved
        _name = State(initialValue: project.name)
        _projectType = State(initialValue: project.projectType ?? "")
        _notes = State(initialValue: project.notes ?? "")
        _coverPhotoUrl = State(initialValue: project.coverPhotoUrl)
        _rooms = State(initialValue: (project.rooms ?? []).sorted { $0.sortOrder < $1.sortOrder })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project name", text: $name)
                    TextField("Project type", text: $projectType)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Cover Photo") {
                    if let coverPhotoUrl, let url = URL(string: coverPhotoUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                            case .failure, .empty: Color.studioSecondary.opacity(0.18)
                            @unknown default: Color.studioSecondary.opacity(0.18)
                            }
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    PhotoSourceMenu(
                        onPhotoUploaded: { url in coverPhotoUrl = url },
                        label: coverPhotoUrl == nil ? "Add Cover Photo" : "Change Cover Photo",
                        systemImage: "photo.badge.plus",
                        style: .bordered
                    )

                    if coverPhotoUrl != nil {
                        Button(role: .destructive) { coverPhotoUrl = nil } label: {
                            Label("Remove Cover Photo", systemImage: "trash")
                        }
                    }
                }

                if !rooms.isEmpty {
                    Section("Rooms") {
                        ForEach(rooms) { room in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(Color.studioSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name)
                                    Text(countLabel(room.selectionCount, singular: "selection"))
                                        .font(.studioCaption(size: 11))
                                        .foregroundStyle(Color.studioSecondary)
                                }
                            }
                        }
                        .onMove { from, to in rooms.move(fromOffsets: from, toOffset: to) }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Color.studioRejected) }
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = try await APIClient.shared.updateProject(
                id: project.id,
                name: trimmedName,
                projectType: projectType.isEmpty ? nil : projectType,
                notes: notes.isEmpty ? nil : notes,
                coverPhotoUrl: coverPhotoUrl,
                clearCoverPhoto: coverPhotoUrl == nil && project.coverPhotoUrl != nil
            )
            let currentOrder = (project.rooms ?? []).sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
            let newOrder = rooms.map(\.id)
            if newOrder != currentOrder {
                _ = try await APIClient.shared.reorderRooms(projectId: project.id, roomIds: newOrder)
            }
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Compact Selection Row

struct SelectionRowCompact: View {
    let selection: SelectionDetail

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(selection.template?.name ?? "Unnamed")
                    .font(.studioCaption(size: 14))
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let vendor = selection.template?.vendor {
                        Text(vendor.name)
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioAccent)
                    }
                    if let vendorSku = selection.template?.sku {
                        Text(vendorSku)
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                    }
                    if let finish = selection.finish {
                        Text("· \(finish.name)")
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                    }
                }
            }

            Spacer()

            if let price = selection.unitPrice {
                PriceText(price * Double(selection.quantity), compact: true)
                    .font(.studioCaption())
            }

            StatusBadge(status: selection.status)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch selection.status {
        case "proposed": return .blue
        case "client_approved": return .green
        case "ordered": return .orange
        case "delivered": return .purple
        case "installed": return .teal
        default: return .secondary
        }
    }
}