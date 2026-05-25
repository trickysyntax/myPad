import Foundation

extension DateFormatter {
    /// Shared ISO 8601 formatter with fractional seconds support.
    static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

extension JSONDecoder {
    /// Configures this decoder to handle ISO 8601 dates with optional fractional seconds.
    func withISO8601DateDecoding() -> Self {
        self.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            // Try with fractional seconds first, then without
            if let date = DateFormatter.iso8601WithFractionalSeconds.date(from: str) {
                return date
            }
            if let date = DateFormatter.iso8601Basic.date(from: str) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO 8601 date string, got: \(str)"
            )
        }
        return self
    }
}
