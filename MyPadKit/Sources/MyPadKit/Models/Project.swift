import Foundation

// MARK: - Reference types (nested in project responses)

public struct ClientRef: Codable, Sendable {
    public let id: String
    public let name: String
}

public struct RoomRef: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sortOrder: Int
    public let selectionCount: Int
    public let spaceCapture: SpaceCaptureSummary?
}

// MARK: - Project Summary (list endpoint)

public struct ProjectSummary: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let clientName: String?
    public let projectType: String?
    public let status: String
    public let budgetTotal: Double?
    public let roomCount: Int
    public let selectionCount: Int
    public let timelineTarget: String?
    public let coverPhotoUrl: String?
    public let spaceCapture: SpaceCaptureSummary?
    public let isArchived: Bool
    public let createdAt: String?
}

// MARK: - Project Detail (single endpoint)

public struct ProjectDetail: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let client: ClientRef?
    public let projectType: String?
    public let status: String
    public let budgetTotal: Double?
    public let markupPct: Double?
    public let timelineStart: String?
    public let timelineTarget: String?
    public let notes: String?
    public let coverPhotoUrl: String?
    public let spaceCapture: SpaceCaptureSummary?
    public let isArchived: Bool
    public let rooms: [RoomRef]?
    public let selectionCount: Int
    public let createdAt: String?
    public let updatedAt: String?
}
