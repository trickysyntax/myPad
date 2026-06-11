import SwiftUI
import MyPadKit

/// Main project list — shows all projects with search and status filter.
struct ProjectListView: View {
    @State private var projects: [ProjectSummary] = []
    @State private var searchText = ""
    @State private var selectedStatus: String? = "active"
    @State private var isLoading = false
    @State private var showCreateProject = false
    @State private var errorMessage: String?
    @State private var useCardView = true

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.studioSurface
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if isLoading && projects.isEmpty {
                        Spacer()
                        ProgressView("Loading projects...")
                        Spacer()
                    } else if let error = errorMessage {
                        EmptyStateView(
                            systemImage: "exclamationmark.triangle",
                            title: "Could Not Load Projects",
                            message: error,
                            actionLabel: "Retry",
                            action: { Task { await loadProjects() } }
                        )
                    } else if projects.isEmpty {
                        EmptyStateView(
                            systemImage: "building.2",
                            title: "No Projects Yet",
                            message: "Create your first project to get started.",
                            actionLabel: "Create Project",
                            action: { showCreateProject = true }
                        )
                    } else {
                        contentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Menu {
                            Button { useCardView.toggle() } label: {
                                Label(useCardView ? "Show List View" : "Show Card View", systemImage: useCardView ? "list.bullet" : "square.grid.2x2")
                            }
                            Button { showCreateProject = true } label: {
                                Label("New Project", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        AccountMenuButton()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search projects...")
            .refreshable { await loadProjects() }
            .sheet(isPresented: $showCreateProject) {
                CreateProjectView { _ in
                    Task { await loadProjects() }
                }
            }
        }
        .task { await loadProjects() }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if useCardView {
            cardView
        } else {
            listView
        }
    }

    // MARK: - Card Grid

    private let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 16)
    ]

    private var cardView: some View {
        ScrollView {
            // Status filter
            StatusFilterPills(selected: $selectedStatus)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredProjects) { project in
                    NavigationLink {
                        ProjectDetailView(projectId: project.id)
                    } label: {
                        ProjectCardView(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - List

    private var listView: some View {
        List {
            // Status filter
            StatusFilterPills(selected: $selectedStatus)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.studioSurface)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            ForEach(filteredProjects) { project in
                NavigationLink {
                    ProjectDetailView(projectId: project.id)
                } label: {
                    ProjectRow(project: project)
                }
                .listRowBackground(Color.studioSurface)
            }
        }
        .scrollContentBackground(.hidden)
                .background(Color.studioSurface)
                .listStyle(.plain)
    }

    private var filteredProjects: [ProjectSummary] {
        var result = projects
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.clientName ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    // MARK: - Data

    private func loadProjects() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.listProjects(
                q: searchText.isEmpty ? nil : searchText,
                status: selectedStatus,
                includeArchived: true,
                limit: 200
            )
            projects = response.data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Status Filter Pills

struct StatusFilterPills: View {
    @Binding var selected: String?

    private let statuses = [
        (nil as String?, "All"),
        ("active", "Active"),
        ("completed", "Completed"),
        ("on_hold", "On Hold"),
        ("archived", "Archived"),
    ] as [(String?, String)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(statuses, id: \.1) { status, label in
                    Button {
                        selected = status
                    } label: {
                        Text(label)
                            .font(.studioCaption(size: 14))
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selected == status
                                    ? Color.studioAccent
                                    : Color.studioSecondary.opacity(0.22)
                            )
                            .foregroundStyle(
                                selected == status ? .white : .primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: ProjectSummary

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)

                if let client = project.clientName {
                    Text(client)
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }

                HStack(spacing: 14) {
                    Label(countLabel(project.roomCount, singular: "room"), systemImage: "square.split.bottomrightquarter")
                    Label(countLabel(project.selectionCount, singular: "selection"), systemImage: "checklist")
                    if let budget = project.budgetTotal {
                        PriceText(budget, compact: true)
                    }
                }
                .font(.studioCaption())
                .foregroundStyle(Color.studioSecondary)
            }

            Spacer()

            if project.isArchived {
                Text("Archived")
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .opacity(project.isArchived ? 0.5 : 1.0)
    }
}

// MARK: - Project Card

struct ProjectCardView: View {
    let project: ProjectSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let urlString = project.coverPhotoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            projectPlaceholder
                        @unknown default:
                            projectPlaceholder
                        }
                    }
                } else {
                    projectPlaceholder
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(2)

                if let client = project.clientName {
                    Text(client)
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 14) {
                    Label(countLabel(project.roomCount, singular: "room"), systemImage: "square.split.bottomrightquarter")
                    Label(countLabel(project.selectionCount, singular: "selection"), systemImage: "checklist")
                }
                .font(.studioCaption())
                .foregroundStyle(Color.studioSecondary)
                .padding(.top, 2)

                HStack {
                    statusPill
                    Spacer()
                    if let budget = project.budgetTotal {
                        PriceText(budget, compact: true)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Color.studioCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.studioDivider.opacity(0.55), lineWidth: 0.5)
        }
        .shadow(color: Color.studioBrown.opacity(0.045), radius: 8, y: 3)
        .opacity(project.isArchived ? 0.5 : 1.0)
    }


    private var projectPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.studioAccent.opacity(0.06))
            Image(systemName: "house.lodge")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.studioAccent.opacity(0.35))
        }
    }

    private var statusPill: some View {
        Text(project.status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.studioCaption(size: 11))
            .fontWeight(.semibold)
            .tracking(0.15)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.studioSecondary.opacity(0.18))
            .foregroundStyle(Color.studioSecondary)
            .clipShape(Capsule())
    }
}

// MARK: - Create Project Sheet (placeholder)

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var clientId = ""
    @State private var projectType = ""
    @State private var isLoading = false

    let onCreated: (ProjectDetail) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Info") {
                    TextField("Project Name", text: $name)
                    TextField("Project Type (optional)", text: $projectType)
                }

                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create Project")
                        }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func create() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let project = try await APIClient.shared.createProject(
                name: name,
                clientId: clientId.isEmpty ? nil : clientId,
                projectType: projectType.isEmpty ? nil : projectType
            )
            onCreated(project)
            dismiss()
        } catch {
            // Error handling would go here
        }
    }
}