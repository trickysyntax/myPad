import SwiftUI
import MyPadKit

private struct DefaultImageResponse: Codable {
    let url: String?
}

/// Adaptive grid of room cards inside a project.
struct RoomGridView: View {
    let projectId: String
    let rooms: [RoomRef]
    var projectCapture: SpaceCaptureSummary? = nil
    var onOpenProjectCapture: (() -> Void)? = nil
    var onCaptureProject: (() -> Void)? = nil
    var onRoomsChanged: (() -> Void)? = nil

    @State private var showAddRoom = false

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SpaceCapturePreviewCard(
                    capture: projectCapture,
                    title: "Project 3D Capture",
                    emptyTitle: "Capture the Project in 3D",
                    emptyMessage: "Scan the full project envelope with a LiDAR iPad to keep spatial context beside rooms and selections.",
                    onOpen: { onOpenProjectCapture?() },
                    onCapture: { onCaptureProject?() }
                )

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(rooms.sorted(by: { $0.sortOrder < $1.sortOrder })) { room in
                        NavigationLink {
                            RoomDetailView(projectId: projectId, roomId: room.id, roomName: room.name)
                        } label: {
                            RoomCard(room: room)
                        }
                        .buttonStyle(.plain)
                    }

                    // Add room button
                    Button {
                        showAddRoom = true
                    } label: {
                        AddRoomCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .sheet(isPresented: $showAddRoom) {
            AddRoomView(projectId: projectId) { _ in
                onRoomsChanged?()
            }
        }
    }
}

// MARK: - Room Card

struct RoomCard: View {
    let room: RoomRef
    @State private var defaultImageUrl: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let defaultImageUrl {
                    AsyncImage(url: defaultImageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            roomIconFallback
                        case .empty:
                            ProgressView()
                        @unknown default:
                            roomIconFallback
                        }
                    }
                } else {
                    roomIconFallback
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(1)

                Text(countLabel(room.selectionCount, singular: "selection"))
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)

                if room.spaceCapture != nil {
                    Label("3D captured", systemImage: "cube.transparent")
                        .font(.studioCaption(size: 12))
                        .foregroundStyle(Color.studioAccent)
                        .padding(.top, 2)
                }
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
        .task {
            await loadDefaultImage()
        }
    }

    private var roomIconFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.studioAccent.opacity(0.06))
            Image(systemName: roomIcon)
                .font(.title)
                .fontWeight(.light)
                .foregroundStyle(Color.studioAccent.opacity(0.4))
        }
    }

    private func loadDefaultImage() async {
        let encoded = room.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? room.name
        let urlString = "\(ServerConfig.baseURL)/api/rooms/default-image?name=\(encoded)"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let result = try? JSONDecoder().decode(DefaultImageResponse.self, from: data),
               let urlString = result.url, let imageUrl = URL(string: urlString) {
                defaultImageUrl = imageUrl
            }
        } catch {}
    }

    private var roomIcon: String {
        let name = room.name.lowercased()
        if name.contains("kitchen") { return "fork.knife" }
        if name.contains("bath") || name.contains("powder") { return "shower" }
        if name.contains("bed") || name.contains("master") || name.contains("suite") { return "bed.double" }
        if name.contains("living") || name.contains("family") { return "sofa" }
        if name.contains("dining") { return "table.furniture" }
        if name.contains("study") || name.contains("office") || name.contains("library") { return "books.vertical" }
        if name.contains("laundry") { return "washer" }
        if name.contains("outdoor") || name.contains("patio") { return "leaf" }
        return "square.split.bottomrightquarter"
    }
}

// MARK: - Add Room Card

struct AddRoomCard: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .frame(height: 100)
                .foregroundStyle(Color.studioSecondary.opacity(0.3))
                .overlay {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(Color.studioSecondary)
                }

            Text("Add Room")
                .font(.studioSubheading())
                .foregroundStyle(Color.studioSecondary)
        }
        .padding(8)
    }
}

// MARK: - Add Room Sheet

struct AddRoomView: View {
    let projectId: String
    let onAdded: (RoomDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var notes = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Room Name") {
                    TextField("e.g. Living Room", text: $name)
                }
                Section("Notes (optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Button("Add Room") {
                        Task { await add() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .navigationTitle("New Room")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func add() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let room = try await APIClient.shared.createRoom(
                projectId: projectId,
                name: name,
                notes: notes.isEmpty ? nil : notes
            )
            onAdded(room)
            dismiss()
        } catch {}
    }
}
