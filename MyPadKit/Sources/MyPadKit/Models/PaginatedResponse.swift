import Foundation

/// Generic paginated response wrapper matching the API's shape:
/// { "total": N, "limit": N, "offset": N, "data": [...] }
public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let total: Int
    public let limit: Int
    public let offset: Int
    public let data: [T]
}
