import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case networkError(Error)
    case transportError(method: String, url: String, underlying: Error)
    case unauthorized

    case serverMessage(String)
    case notFound
    case conflict

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .transportError(let method, let url, let underlying):
            return "Network error on \(method) \(url): \(underlying.localizedDescription)"
        case .unauthorized:
            return "Unauthorized — please log in again"
        case .serverMessage(let msg):
            return msg
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Conflict — the resource may have been modified"
        }
    }
}
