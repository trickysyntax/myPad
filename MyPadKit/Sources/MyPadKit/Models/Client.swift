import Foundation

// MARK: - Client Project Reference (nested in detail)

public struct ClientProjectRef: Codable, Sendable {
    public let id: String
    public let name: String
    public let status: String
    public let timelineTarget: String?
}

// MARK: - Client Summary (list endpoint)

public struct ClientSummary: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let email: String?
    public let phone: String?
    public let projectCount: Int
    public let createdAt: String?
}

// MARK: - Client Detail (single endpoint)

public struct ClientDetail: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let email: String?
    public let phone: String?
    public let billingAddress: String?
    public let siteAddress: String?
    public let notes: String?
    public let projects: [ClientProjectRef]?
    public let createdAt: String?
    public let updatedAt: String?
}
