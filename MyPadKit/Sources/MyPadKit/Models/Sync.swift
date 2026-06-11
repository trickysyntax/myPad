import Foundation

public struct SyncEnvelope: Codable, Sendable {
    public let syncVersion: Int
    public let mode: String
    public let serverTime: String
    public let snapshotWatermark: String?
    public let since: String?
    public let highWatermark: String?
    public let nextCursor: String?
    public let hasMore: Bool
    public let data: SyncPayload
    public let tombstones: [SyncTombstone]
}

public struct SyncPayload: Codable, Sendable {
    public let vendors: [SyncVendor]
    public let assetTemplates: [AssetTemplateSummary]
    public let assetFinishes: [AssetFinishSummary]
    public let clients: [SyncClient]
    public let projects: [SyncProject]
    public let rooms: [RoomDetail]
    public let selections: [SelectionDetail]
    public let selectionFinishes: [SelectionFinish]

    public init(
        vendors: [SyncVendor],
        assetTemplates: [AssetTemplateSummary],
        assetFinishes: [AssetFinishSummary],
        clients: [SyncClient],
        projects: [SyncProject],
        rooms: [RoomDetail],
        selections: [SelectionDetail],
        selectionFinishes: [SelectionFinish] = []
    ) {
        self.vendors = vendors
        self.assetTemplates = assetTemplates
        self.assetFinishes = assetFinishes
        self.clients = clients
        self.projects = projects
        self.rooms = rooms
        self.selections = selections
        self.selectionFinishes = selectionFinishes
    }

    enum CodingKeys: String, CodingKey {
        case vendors
        case assetTemplates
        case assetFinishes
        case clients
        case projects
        case rooms
        case selections
        case selectionFinishes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vendors = try container.decode([SyncVendor].self, forKey: .vendors)
        assetTemplates = try container.decode([AssetTemplateSummary].self, forKey: .assetTemplates)
        assetFinishes = try container.decode([AssetFinishSummary].self, forKey: .assetFinishes)
        clients = try container.decode([SyncClient].self, forKey: .clients)
        projects = try container.decode([SyncProject].self, forKey: .projects)
        rooms = try container.decode([RoomDetail].self, forKey: .rooms)
        selections = try container.decode([SelectionDetail].self, forKey: .selections)
        selectionFinishes = try container.decodeIfPresent([SelectionFinish].self, forKey: .selectionFinishes) ?? []
    }
}

public struct SyncTombstone: Codable, Sendable {
    public let entityType: String
    public let entityId: String
    public let deletedAt: String
}

public struct SyncVendor: Codable, Identifiable, Sendable {
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
    public let isActive: Bool
    public let createdAt: String?
    public let updatedAt: String?
}

public struct SyncClient: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let email: String?
    public let phone: String?
    public let billingAddress: String?
    public let siteAddress: String?
    public let notes: String?
    public let projectCount: Int?
    public let createdAt: String?
    public let updatedAt: String?
}

public struct SyncProject: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let client: ClientRef?
    public let clientId: String?
    public let projectType: String?
    public let status: String
    public let budgetTotal: Double?
    public let markupPct: Double?
    public let timelineStart: String?
    public let timelineTarget: String?
    public let notes: String?
    public let coverPhotoUrl: String?
    public let spaceCapture: SpaceCaptureSummary?
    public let isArchived: Bool
    public let roomCount: Int
    public let selectionCount: Int
    public let createdAt: String?
    public let updatedAt: String?
}
