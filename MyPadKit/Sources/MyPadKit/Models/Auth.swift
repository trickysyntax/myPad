import Foundation

// MARK: - Auth tokens

public struct AuthTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String
    public let expiresIn: Int?
}

// MARK: - Login request

public struct LoginRequest: Codable, Sendable {
    public let username: String
    public let password: String
}

// MARK: - Upload response

public struct UploadResponse: Codable, Sendable {
    public let filename: String
    public let url: String?
    public let path: String?
    public let size: Int?
}

// MARK: - Generic delete response

public struct DeleteResponse: Codable, Sendable {
    public let deleted: Bool
    public let id: String
}

// MARK: - Archive response

public struct ArchiveResponse: Codable, Sendable {
    public let archived: Bool
    public let id: String
}
