import Foundation

// MARK: - Vendor Summary (list endpoint)

public struct VendorSummary: Codable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let category: String?
    public let pricingTier: String?
    public let tags: [String]?
    public let website: String?
    public let logoUrl: String?
}

// MARK: - Vendor Detail (single endpoint)

public struct VendorDetail: Codable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let category: String?
    public let pricingTier: String?
    public let pricingDetail: String?
    public let targetMarket: String?
    public let creditTerms: String?
    public let knownFor: String?
    public let leadership: String?
    public let website: String?
    public let logoUrl: String?
    public let address: String?
    public let email: String?
    public let phone: String?
    public let socials: String?
    public let prose: String?
    public let tags: [String]?
    public let sources: [String]?
}
