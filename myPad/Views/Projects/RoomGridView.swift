import SwiftUI
import MyPadKit

/// Adaptive grid of room cards inside a project.
struct RoomGridView: View {
    let projectId: String
    let rooms: [RoomRef]
    var onRoomsChanged: (() -> Void)? = nil

    @State private var showAddRoom = false

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
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
            .padding(.horizontal, 20)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.studioAccent.opacity(0.06))
                Image(systemName: roomIcon)
                    .font(.title)
                    .fontWeight(.light)
                    .foregroundStyle(Color.studioAccent.opacity(0.4))
            }
            .frame(height: 100)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(1)

                Text(countLabel(room.selectionCount, singular: "selection"))
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)
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
