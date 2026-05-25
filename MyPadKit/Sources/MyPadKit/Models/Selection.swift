import Foundation

// MARK: - Nested reference types

public struct TemplateRef: Codable, Sendable {
    public let id: String
    public let name: String
    public let sku: String?
    public let vendor: VendorRef?
    public let category: String?
    public let dimensions: String?
    public let leadTimeWeeks: Int?
    public let specSheetUrl: String?
    public let imageUrls: [String]?
}

public struct FinishRef: Codable, Sendable {
    public let id: String
    public let name: String
    public let finishType: String
}

public struct SelectionFinish: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let selectionId: String
    public let assetFinishId: String?
    public let assetTemplateId: String?
    public let name: String
    public let finishType: String
    public let source: String?
    public let vendor: String?
    public let patternColor: String?
    public let grade: String?
    public let width: String?
    public let `repeat`: String?
    public let railroad: Bool?
    public let yardage: String?
    public let netPrice: String?
    public let markup: String?
    public let salePrice: String?
    public let shipTo: String?
    public let photoUrl: String?
    public let swatchImageUrl: String?
    public let imageUrls: [String]?
    public let isSelected: Bool
    public let sortOrder: Int?
    public let createdAt: String?
    public let updatedAt: String?
}

public struct SelectionFinishListResponse: Codable, Sendable {
    public let data: [SelectionFinish]
}

public struct RoomNameRef: Codable, Sendable {
    public let id: String
    public let name: String
}

// MARK: - Selection Detail

public struct SelectionDetail: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let roomId: String?
    public let assetTemplateId: String?
    public let finishId: String?
    public let quantity: Int
    public let unitPrice: Double?
    public let markupPct: Double?
    public let status: String
    public let notes: String?
    public let clientNotes: String?
    public let instructions: String?
    public let shipTo: String?
    public let comShipTo: String?
    public let sourceUrl: String?
    public let attachments: [String]?
    public let isHidden: Bool
    public let groupKey: String?
    public let rank: Int?
    public let isSelected: Bool
    public let template: TemplateRef?
    public let finish: FinishRef?
    public let finishes: [SelectionFinish]?
    public let room: RoomNameRef?
    public let createdAt: String?
    public let updatedAt: String?
}

// MARK: - Selection list wrapper

/// The selections endpoint returns { "data": [SelectionDetail] }
public struct SelectionListResponse: Codable, Sendable {
    public let data: [SelectionDetail]
}
