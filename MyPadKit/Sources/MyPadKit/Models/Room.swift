import Foundation

public struct RoomDetail: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let projectId: String
    public let name: String
    public let sortOrder: Int
    public let floorPlanUrl: String?
    public let photoUrls: [String]?
    public let notes: String?
    public let selectionCount: Int
    public let createdAt: String?
    public let updatedAt: String?
}
