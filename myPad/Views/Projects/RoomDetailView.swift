import SwiftUI
import MyPadKit

/// Room detail with list of selections, grouped by status and candidate groups.
struct RoomDetailView: View {
    let projectId: String
    let roomId: String
    let roomName: String

    @State private var selections: [SelectionDetail] = []
    @State private var isLoading = true
    @State private var selectedStatus: String? = nil
    @State private var showAddSelection = false
    @State private var showCaptureRoom = false
    @State private var viewingCapture: SpaceCaptureSummary?
    @State private var showRemoveCaptureConfirm = false
    @State private var roomPhotoUrls: [String] = []
    @State private var spaceCapture: SpaceCaptureSummary?
    @State private var collapsedGroups: Set<String> = []

    private let api = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if selections.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        EmptyStateView(
                            systemImage: "checklist",
                            title: "No Selections",
                            message: "Add your first selection to this room.",
                            actionLabel: "Add Selection",
                            action: { showAddSelection = true }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .background(Color.studioSurface)
            } else {
                selectionList
            }
        }
        .sheet(isPresented: $showAddSelection) {
            NavigationStack {
                AssetSearchView(
                    autoAddProjectId: projectId,
                    autoAddRoomId: roomId,
                    autoAddRoomName: roomName
                )
            }
        }
        .sheet(isPresented: $showCaptureRoom) {
            SpaceCaptureSheet(scope: .room(projectId: projectId, roomId: roomId, name: roomName)) { _ in
                Task { await load() }
            }
        }
        .sheet(item: $viewingCapture) { capture in
            SpaceCaptureViewer(capture: capture)
        }
        .onChange(of: showAddSelection) { _, isPresented in
            if !isPresented {
                Task { await load() }
            }
        }
        .navigationTitle(roomName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddSelection = true
                    } label: {
                        Label("New Selection", systemImage: "plus.circle")
                    }

                    Divider()

                    Button {
                        showCaptureRoom = true
                    } label: {
                        Label(spaceCapture == nil ? "Capture 3D Room" : "Recapture 3D Room", systemImage: "cube.transparent")
                    }

                    if spaceCapture != nil {
                        Button(role: .destructive) {
                            showRemoveCaptureConfirm = true
                        } label: {
                            Label("Remove 3D Capture", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let capture = spaceCapture {
                Button {
                    viewingCapture = capture
                } label: {
                    Label("View 3D", systemImage: "cube.transparent")
                        .font(.studioCaption(size: 13))
                }
                .buttonStyle(WhiteBubbleButtonStyle())
                .padding(20)
            } else {
                Button {
                    showCaptureRoom = true
                } label: {
                    Label("Capture 3D", systemImage: "cube.transparent")
                        .font(.studioCaption(size: 13))
                }
                .buttonStyle(WhiteBubbleButtonStyle())
                .padding(20)
            }
        }
        .confirmationDialog(
            "Remove this 3D capture?",
            isPresented: $showRemoveCaptureConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove 3D Capture", role: .destructive) {
                Task { await removeRoomCapture() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current room capture will be hidden. You can capture the room again from the menu.")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Selection List

    private var selectionList: some View {
        List {
            // Room photos
            if !roomPhotoUrls.isEmpty {
                Section {
                    PhotoGalleryRow(photoUrls: roomPhotoUrls) { index in
                        Task { await removeRoomPhoto(at: index) }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Status filter pills
            SelectionStatusFilter(selected: $selectedStatus)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.studioSurface)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            // Group by candidate group, then list individually
            ForEach(groupedSelections, id: \.0) { groupKey, groupSelections in
                if let groupKey, !groupKey.isEmpty {
                    groupSection(groupKey: groupKey, selections: groupSelections)
                } else {
                    ForEach(groupSelections) { selection in
                        SelectionRow(selection: selection, projectId: projectId, roomId: roomId)
                            .listRowBackground(Color.studioSurface)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
                .background(Color.studioSurface)
                .listStyle(.plain)
    }

    // MARK: - Group Section

    private func groupSection(groupKey: String, selections: [SelectionDetail]) -> AnyView {
        let placeholder = selections.first(where: { $0.template == nil })
        let candidates = selections.filter { $0.template != nil }
        let winner = candidates.first(where: { $0.isSelected })
        let hasWinner = winner != nil
        let isExpanded = !collapsedGroups.contains(groupKey)

        return AnyView(
            Group {
                if hasWinner, !isExpanded {
                    WinnerSummaryRow(
                        winner: winner!,
                        groupName: groupKey,
                        candidateCount: candidates.count,
                        projectId: projectId,
                        roomId: roomId
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            _ = collapsedGroups.remove(groupKey)
                        }
                    }
                    .listRowBackground(Color.studioSurface)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                _ = collapsedGroups.insert(groupKey)
                            } else {
                                _ = collapsedGroups.remove(groupKey)
                            }
                        }
                    } label: {
                        PlaceholderRow(
                            name: placeholder?.template?.name ?? groupKey,
                            isExpanded: isExpanded,
                            candidateCount: candidates.count,
                            hasWinner: hasWinner
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.studioSurface)

                    if isExpanded {
                        ForEach(candidates) { candidate in
                            CandidateRow(
                                selection: candidate,
                                projectId: projectId,
                                roomId: roomId,
                                isWinner: candidate.isSelected,
                                greyedOut: hasWinner && !candidate.isSelected
                            )
                            .listRowBackground(Color.studioSurface)
                        }
                    }
                }
            }
        )
    }

    /// Group selections by groupKey; nil or empty = ungrouped.
    private var groupedSelections: [(String?, [SelectionDetail])] {
        let filtered = selectedStatus == nil
            ? selections
            : selections.filter { $0.status == selectedStatus }

        let grouped = Dictionary(grouping: filtered) { $0.groupKey }
        // Sort: groups with a key first, then ungrouped
        return grouped.sorted { a, b in
            if a.key == nil { return false }
            if b.key == nil { return true }
            return (a.key ?? "") < (b.key ?? "")
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            selections = try await api.listSelections(
                projectId: projectId, roomId: roomId, status: selectedStatus
            )
            // Auto-collapse groups that have a winner
            for selection in selections {
                if let key = selection.groupKey, !key.isEmpty, selection.isSelected {
                    collapsedGroups.insert(key)
                }
            }
        } catch {}

        // Load room photoUrls and current 3D capture
        do {
            let room = try await api.getRoom(projectId: projectId, roomId: roomId)
            roomPhotoUrls = room.photoUrls ?? []
            spaceCapture = room.spaceCapture
        } catch {}
    }

    private func removeRoomCapture() async {
        do {
            _ = try await api.deleteRoomSpaceCapture(projectId: projectId, roomId: roomId)
            spaceCapture = nil
            await load()
        } catch {}
    }

    // MARK: - Room Photos

    private func addRoomPhoto(_ url: String) async {
        let updated = roomPhotoUrls + [url]
        roomPhotoUrls = updated
        await persistRoomPhotos(updated)
    }

    private func removeRoomPhoto(at index: Int) async {
        var updated = roomPhotoUrls
        updated.remove(at: index)
        roomPhotoUrls = updated
        await persistRoomPhotos(updated)
    }

    private func persistRoomPhotos(_ photoUrls: [String]) async {
        do {
            _ = try await api.updateRoom(
                projectId: projectId,
                roomId: roomId,
                photoUrls: photoUrls
            )
        } catch {}
    }
}

// MARK: - Status Filter

struct SelectionStatusFilter: View {
    @Binding var selected: String?

    private let statuses: [(String?, String)] = [
        (nil, "All"),
        ("proposed", "Proposed"),
        ("client_approved", "Approved"),
        ("ordered", "Ordered"),
        ("delivered", "Delivered"),
        ("installed", "Installed"),
    ]

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
                            .background(selected == status ? Color.studioAccent : Color.studioSecondary.opacity(0.22))
                            .foregroundStyle(selected == status ? Color.white : Color.studioText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private extension SelectionDetail {
    var previewImageURL: URL? {
        if let sourceUrl, let url = URL(string: sourceUrl) {
            return url
        }
        if let templateURL = template?.imageUrls?.first, let url = URL(string: templateURL) {
            return url
        }
        if let attachmentURL = attachments?.first, let url = URL(string: attachmentURL) {
            return url
        }
        return nil
    }
}

// MARK: - Selection Row

struct SelectionRow: View {
    let selection: SelectionDetail
    let projectId: String
    let roomId: String

    var body: some View {
        NavigationLink {
            SelectionDetailView(selection: selection, projectId: projectId, roomId: roomId)
        } label: {
            HStack(spacing: 12) {
                // Thumbnail with approved badge
                ZStack(alignment: .bottomTrailing) {
                    AsyncImageLoader(
                        url: selection.previewImageURL,
                        size: CGSize(width: 52, height: 52)
                    )
                    if selection.status == "client_approved" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.studioApproved).frame(width: 16, height: 16))
                            .clipShape(Circle())
                            .padding([.trailing, .bottom], 5)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(selection.template?.name ?? "Unknown")
                        .font(.studioSubheading())
                        .foregroundStyle(Color.studioText)
                        .lineLimit(1)

                    Text(selection.template?.vendor?.name ?? "Style Source")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioAccent)
                        .lineLimit(1)

                    if let finish = selection.finish {
                        Text(finish.name)
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text("Qty \(selection.quantity)")
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)

                        if let price = selection.unitPrice {
                            PriceText(price * Double(selection.quantity), compact: true)
                                .font(.studioCaption(size: 11))
                        }

                        Spacer()
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: selection.status)
                    if selection.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.studioApproved)
                            .font(.studioCaption())
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Placeholder Row (parent item in a candidate group)

struct PlaceholderRow: View {
    let name: String
    let isExpanded: Bool
    let candidateCount: Int
    let hasWinner: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.fill")
                .font(.title3)
                .foregroundStyle(Color.studioAccent.opacity(0.5))
                .frame(width: 52, height: 52)
                .background(Color.studioAccent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(1)

                Text("\(candidateCount) option\(candidateCount == 1 ? "" : "s")")
                    .font(.studioCaption(size: 11))
                    .foregroundStyle(Color.studioSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.studioCaption())
                .fontWeight(.semibold)
                .foregroundStyle(Color.studioSecondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Winner Summary Row (collapsed group with selected candidate)

struct WinnerSummaryRow: View {
    let winner: SelectionDetail
    let groupName: String
    let candidateCount: Int
    let projectId: String
    let roomId: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail with approved badge
                ZStack(alignment: .bottomTrailing) {
                    AsyncImageLoader(
                        url: winner.previewImageURL,
                        size: CGSize(width: 52, height: 52)
                    )
                    if winner.status == "client_approved" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.studioApproved).frame(width: 16, height: 16))
                            .clipShape(Circle())
                            .padding([.trailing, .bottom], 5)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(winner.template?.name ?? groupName)
                        .font(.studioSubheading())
                        .foregroundStyle(Color.studioText)
                        .lineLimit(1)

                    Text(winner.template?.vendor?.name ?? "Style Source")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioAccent)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("Qty \(winner.quantity)")
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)

                        if let price = winner.unitPrice {
                            PriceText(price * Double(winner.quantity), compact: true)
                                .font(.studioCaption(size: 11))
                        }

                        Spacer()
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: winner.status)

                    Text("\(candidateCount) option\(candidateCount == 1 ? "" : "s")")
                        .font(.studioCaption(size: 11))
                        .fontWeight(.medium)
                        .foregroundStyle(Color.studioAccent)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Candidate Row (indented option in a candidate group)

struct CandidateRow: View {
    let selection: SelectionDetail
    let projectId: String
    let roomId: String
    let isWinner: Bool
    let greyedOut: Bool

    var body: some View {
        NavigationLink {
            SelectionDetailView(selection: selection, projectId: projectId, roomId: roomId)
        } label: {
            HStack(spacing: 12) {
                // Indent to align icon with parent row text (52 icon + 12 gap = 64)
                Color.clear.frame(width: 64, height: 1)

                // Thumbnail with approved badge
                ZStack(alignment: .bottomTrailing) {
                    AsyncImageLoader(
                        url: selection.previewImageURL,
                        size: CGSize(width: 40, height: 40)
                    )
                    .opacity(greyedOut ? 0.35 : 1.0)
                    if !greyedOut, selection.status == "client_approved" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.studioApproved).frame(width: 13, height: 13))
                            .clipShape(Circle())
                            .padding([.trailing, .bottom], 5)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(selection.template?.name ?? "Unnamed")
                        .font(.studioSubheading())
                        .foregroundStyle(greyedOut ? .secondary : Color.studioText)
                        .lineLimit(1)

                    Text(selection.template?.vendor?.name ?? "Style Source")
                        .font(.studioCaption(size: 11))
                        .foregroundStyle(greyedOut ? Color.studioSecondary.opacity(0.5) : Color.studioAccent)
                        .lineLimit(1)
                }

                Spacer()

                if let price = selection.unitPrice {
                    PriceText(price * Double(selection.quantity), compact: true)
                        .font(.studioCaption(size: 11))
                        .opacity(greyedOut ? 0.35 : 1.0)
                }

                if isWinner {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.studioAccent)
                        .font(.studioCaption(size: 14))
                } else if greyedOut {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary.opacity(0.3))
                        .font(.studioCaption(size: 14))
                }
            }
            .padding(.vertical, 4)
        }
    }
}