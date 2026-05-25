import Foundation

public struct AssetFinishSummary: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let assetTemplateId: String
    public let name: String
    public let finishType: String
    public let upchargePct: Double?
    public let grade: String?
    public let width: String?
    public let `repeat`: String?
    public let railroad: Bool?
    public let source: String?
    public let vendor: String?
    public let patternColor: String?
    public let yardage: String?
    public let netPrice: String?
    public let markup: String?
    public let salePrice: String?
    public let shipTo: String?
    public let photoUrl: String?
    public let inStock: Bool
    public let swatchImageUrl: String?
    public let imageUrls: [String]?
    public let sortOrder: Int
    public let createdAt: String?
    public let updatedAt: String?
}

public struct AssetFinishListResponse: Codable, Sendable {
    public let data: [AssetFinishSummary]
}
