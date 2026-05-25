import Foundation

// MARK: - Vendor reference (nested)

public struct VendorRef: Codable, Sendable {
    public let id: String
    public let name: String
}

// MARK: - Asset Template Summary (list endpoint)

public struct AssetTemplateSummary: Codable, Identifiable, Sendable {
    public let id: String
    public let vendorId: String?
    public let vendor: VendorRef?
    public let name: String
    public let sku: String?
    public let category: String?
    public let description: String?
    public let msrp: Double?
    public let tradePrice: Double?
    public let leadTimeWeeks: Int?
    public let minimumOrder: String?
    public let dimensions: String?
    public let careInstructions: String?
    public let imageUrls: [String]?
    public let specSheetUrl: String?
    public let isDiscontinued: Bool
    public let finishCount: Int
    public let createdAt: String?
    public let updatedAt: String?
}

// MARK: - Asset Template Detail (single endpoint, includes finishes)

public struct AssetTemplateDetail: Codable, Identifiable, Sendable {
    public let id: String
    public let vendorId: String?
    public let vendor: VendorRef?
    public let name: String
    public let sku: String?
    public let category: String?
    public let description: String?
    public let msrp: Double?
    public let tradePrice: Double?
    public let leadTimeWeeks: Int?
    public let minimumOrder: String?
    public let dimensions: String?
    public let careInstructions: String?
    public let imageUrls: [String]?
    public let specSheetUrl: String?
    public let isDiscontinued: Bool
    public let finishCount: Int
    public let createdAt: String?
    public let updatedAt: String?
    public let finishes: [AssetFinishSummary]
}
