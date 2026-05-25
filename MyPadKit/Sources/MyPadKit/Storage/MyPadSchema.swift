import Foundation
import SwiftData

// MARK: - SwiftData Models

/// Local mirror of Vendor. Stores the full detail shape so both list and detail views
/// can read from the same local store.
@Model
public final class SDVendor {
    @Attribute(.unique) public var id: String
    var slug: String
    var name: String
    var category: String?
    var pricingTier: String?
    var pricingDetail: String?
    var targetMarket: String?
    var creditTerms: String?
    var knownFor: String?
    var leadership: String?
    var website: String?
    var address: String?
    var email: String?
    var phone: String?
    var socials: String?
    var prose: String?
    var tags: [String]
    var sources: [String]
    var isActive: Bool
    var lastSyncedAt: Date
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: String, slug: String, name: String, category: String? = nil,
        pricingTier: String? = nil, pricingDetail: String? = nil,
        targetMarket: String? = nil, creditTerms: String? = nil,
        knownFor: String? = nil, leadership: String? = nil,
        website: String? = nil, address: String? = nil,
        email: String? = nil, phone: String? = nil,
        socials: String? = nil, prose: String? = nil,
        tags: [String] = [], sources: [String] = [],
        isActive: Bool = true, lastSyncedAt: Date = .now,
        createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.category = category
        self.pricingTier = pricingTier
        self.pricingDetail = pricingDetail
        self.targetMarket = targetMarket
        self.creditTerms = creditTerms
        self.knownFor = knownFor
        self.leadership = leadership
        self.website = website
        self.address = address
        self.email = email
        self.phone = phone
        self.socials = socials
        self.prose = prose
        self.tags = tags
        self.sources = sources
        self.isActive = isActive
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Upsert from API detail response.
    convenience init(from detail: VendorDetail) {
        self.init(
            id: detail.id, slug: detail.slug, name: detail.name,
            category: detail.category, pricingTier: detail.pricingTier,
            pricingDetail: detail.pricingDetail, targetMarket: detail.targetMarket,
            creditTerms: detail.creditTerms, knownFor: detail.knownFor,
            leadership: detail.leadership, website: detail.website,
            address: detail.address, email: detail.email,
            phone: detail.phone, socials: detail.socials,
            prose: detail.prose, tags: detail.tags ?? [],
            sources: detail.sources ?? []
        )
    }
}

@Model
public final class SDAssetTemplate {
    @Attribute(.unique) public var id: String
    var vendorId: String?
    var vendorName: String?
    var name: String
    var sku: String?
    var category: String?
    var descriptionText: String?  // "description" is reserved
    var msrp: Double?
    var tradePrice: Double?
    var leadTimeWeeks: Int?
    var minimumOrder: String?
    var dimensions: String?
    var careInstructions: String?
    var imageUrls: [String]
    var specSheetUrl: String?
    var isDiscontinued: Bool
    var finishCount: Int
    var lastSyncedAt: Date
    var createdAt: Date?
    var updatedAt: Date?

    @Relationship(deleteRule: .cascade)
    var finishes: [SDAssetFinish]?

    init(
        id: String, vendorId: String? = nil, vendorName: String? = nil,
        name: String, sku: String? = nil, category: String? = nil,
        descriptionText: String? = nil, msrp: Double? = nil,
        tradePrice: Double? = nil, leadTimeWeeks: Int? = nil,
        minimumOrder: String? = nil, dimensions: String? = nil,
        careInstructions: String? = nil, imageUrls: [String] = [],
        specSheetUrl: String? = nil, isDiscontinued: Bool = false,
        finishCount: Int = 0, lastSyncedAt: Date = .now,
        createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id
        self.vendorId = vendorId
        self.vendorName = vendorName
        self.name = name
        self.sku = sku
        self.category = category
        self.descriptionText = descriptionText
        self.msrp = msrp
        self.tradePrice = tradePrice
        self.leadTimeWeeks = leadTimeWeeks
        self.minimumOrder = minimumOrder
        self.dimensions = dimensions
        self.careInstructions = careInstructions
        self.imageUrls = imageUrls
        self.specSheetUrl = specSheetUrl
        self.isDiscontinued = isDiscontinued
        self.finishCount = finishCount
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SDAssetFinish {
    @Attribute(.unique) public var id: String
    var assetTemplateId: String
    var name: String
    var finishType: String
    var upchargePct: Double?
    var grade: String?
    var width: String?
    var repeatText: String?
    var railroad: Bool?
    var source: String?
    var vendor: String?
    var patternColor: String?
    var yardage: String?
    var netPrice: String?
    var markup: String?
    var salePrice: String?
    var shipTo: String?
    var photoUrl: String?
    var inStock: Bool
    var swatchImageUrl: String?
    var imageUrls: [String]
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: String, assetTemplateId: String, name: String,
        finishType: String, upchargePct: Double? = nil,
        grade: String? = nil, width: String? = nil,
        repeatText: String? = nil, railroad: Bool? = nil,
        source: String? = nil, vendor: String? = nil,
        patternColor: String? = nil, yardage: String? = nil,
        netPrice: String? = nil, markup: String? = nil,
        salePrice: String? = nil, shipTo: String? = nil,
        photoUrl: String? = nil, inStock: Bool = true,
        swatchImageUrl: String? = nil, imageUrls: [String] = [],
        sortOrder: Int = 0, createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.assetTemplateId = assetTemplateId
        self.name = name
        self.finishType = finishType
        self.upchargePct = upchargePct
        self.grade = grade
        self.width = width
        self.repeatText = repeatText
        self.railroad = railroad
        self.source = source
        self.vendor = vendor
        self.patternColor = patternColor
        self.yardage = yardage
        self.netPrice = netPrice
        self.markup = markup
        self.salePrice = salePrice
        self.shipTo = shipTo
        self.photoUrl = photoUrl
        self.inStock = inStock
        self.swatchImageUrl = swatchImageUrl
        self.imageUrls = imageUrls
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SDSelectionFinish {
    @Attribute(.unique) public var id: String
    var selectionId: String
    var assetFinishId: String?
    var assetTemplateId: String?
    var name: String
    var finishType: String
    var source: String?
    var vendor: String?
    var patternColor: String?
    var grade: String?
    var width: String?
    var repeatText: String?
    var railroad: Bool?
    var yardage: String?
    var netPrice: String?
    var markup: String?
    var salePrice: String?
    var shipTo: String?
    var photoUrl: String?
    var swatchImageUrl: String?
    var imageUrls: [String]
    var isSelected: Bool
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: String, selectionId: String, assetFinishId: String? = nil,
        assetTemplateId: String? = nil, name: String, finishType: String,
        source: String? = nil, vendor: String? = nil, patternColor: String? = nil,
        grade: String? = nil, width: String? = nil, repeatText: String? = nil,
        railroad: Bool? = nil, yardage: String? = nil, netPrice: String? = nil,
        markup: String? = nil, salePrice: String? = nil, shipTo: String? = nil,
        photoUrl: String? = nil, swatchImageUrl: String? = nil, imageUrls: [String] = [],
        isSelected: Bool = true, sortOrder: Int = 0, createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id
        self.selectionId = selectionId
        self.assetFinishId = assetFinishId
        self.assetTemplateId = assetTemplateId
        self.name = name
        self.finishType = finishType
        self.source = source
        self.vendor = vendor
        self.patternColor = patternColor
        self.grade = grade
        self.width = width
        self.repeatText = repeatText
        self.railroad = railroad
        self.yardage = yardage
        self.netPrice = netPrice
        self.markup = markup
        self.salePrice = salePrice
        self.shipTo = shipTo
        self.photoUrl = photoUrl
        self.swatchImageUrl = swatchImageUrl
        self.imageUrls = imageUrls
        self.isSelected = isSelected
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SDSyncState {
    @Attribute(.unique) public var id: String
    var completedCursor: String?
    var completedHighWatermark: String?
    var lastBootstrapAt: Date?
    var lastChangesAt: Date?
    var updatedAt: Date

    init(
        id: String = "default",
        completedCursor: String? = nil,
        completedHighWatermark: String? = nil,
        lastBootstrapAt: Date? = nil,
        lastChangesAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.completedCursor = completedCursor
        self.completedHighWatermark = completedHighWatermark
        self.lastBootstrapAt = lastBootstrapAt
        self.lastChangesAt = lastChangesAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SDClient {
    @Attribute(.unique) public var id: String
    var name: String
    var email: String?
    var phone: String?
    var billingAddress: String?
    var siteAddress: String?
    var notes: String?
    var projectCount: Int
    var lastSyncedAt: Date
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: String, name: String, email: String? = nil,
        phone: String? = nil, billingAddress: String? = nil,
        siteAddress: String? = nil, notes: String? = nil,
        projectCount: Int = 0, lastSyncedAt: Date = .now,
        createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.billingAddress = billingAddress
        self.siteAddress = siteAddress
        self.notes = notes
        self.projectCount = projectCount
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SDProject {
    @Attribute(.unique) public var id: String
    var name: String
    var clientId: String?
    var clientName: String?
    var projectType: String?
    var status: String
    var budgetTotal: Double?
    var markupPct: Double?
    var timelineStart: Date?
    var timelineTarget: Date?
    var notes: String?
    var isArchived: Bool
    var roomCount: Int
    var selectionCount: Int
    var lastSyncedAt: Date
    var createdAt: Date?
    var updatedAt: Date?

    @Relationship(deleteRule: .cascade)
    var rooms: [SDRoom]?

    @Relationship(deleteRule: .cascade)
    var selections: [SDSelection]?

    init(
        id: String, name: String, clientId: String? = nil,
        clientName: String? = nil, projectType: String? = nil,
        status: String = "active", budgetTotal: Double? = nil,
        markupPct: Double? = nil, timelineStart: Date? = nil,
        timelineTarget: Date? = nil, notes: String? = nil,
        isArchived: Bool = false, roomCount: Int = 0,
        selectionCount: Int = 0, lastSyncedAt: Date = .now,
        createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.clientId = clientId
        self.clientName = clientName
        self.projectType = projectType
        self.status = status
        self.budgetTotal = budgetTotal
        self.markupPct = markupPct
        self.timelineStart = timelineStart
        self.timelineTarget = timelineTarget
        self.notes = notes
        self.isArchived = isArchived
        self.roomCount = roomCount
        self.selectionCount = selectionCount
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SDRoom {
    @Attribute(.unique) public var id: String
    var projectId: String
    var name: String
    var sortOrder: Int
    var floorPlanUrl: String?
    var photoUrls: [String]
    var notes: String?
    var selectionCount: Int
    var createdAt: Date?
    var updatedAt: Date?

    @Relationship(deleteRule: .cascade)
    var selections: [SDSelection]?

    init(
        id: String, projectId: String, name: String,
        sortOrder: Int = 0, floorPlanUrl: String? = nil,
        photoUrls: [String] = [], notes: String? = nil,
        selectionCount: Int = 0, createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.sortOrder = sortOrder
        self.floorPlanUrl = floorPlanUrl
        self.photoUrls = photoUrls
        self.notes = notes
        self.selectionCount = selectionCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SDSelection {
    @Attribute(.unique) public var id: String
    var projectId: String
    var roomId: String?
    var assetTemplateId: String?
    var finishId: String?
    var quantity: Int
    var unitPrice: Double?
    var markupPct: Double?
    var status: String
    var notes: String?
    var clientNotes: String?
    var instructions: String?
    var shipTo: String?
    var comShipTo: String?
    var sourceUrl: String?
    var isHidden: Bool
    var groupKey: String?
    var rank: Int?
    var isSelected: Bool

    // Denormalized display fields
    var templateName: String?
    var templateSku: String?
    var finishName: String?
    var finishType: String?
    var roomName: String?

    var createdAt: Date?
    var updatedAt: Date?

    // Sync tracking
    var needsSync: Bool
    var syncConflict: Bool

    init(
        id: String, projectId: String, roomId: String? = nil,
        assetTemplateId: String? = nil, finishId: String? = nil,
        quantity: Int = 1, unitPrice: Double? = nil,
        markupPct: Double? = nil, status: String = "proposed",
        notes: String? = nil, clientNotes: String? = nil,
        instructions: String? = nil, shipTo: String? = nil,
        comShipTo: String? = nil, sourceUrl: String? = nil,
        isHidden: Bool = false, groupKey: String? = nil,
        rank: Int? = nil, isSelected: Bool = false,
        templateName: String? = nil, templateSku: String? = nil,
        finishName: String? = nil, finishType: String? = nil,
        roomName: String? = nil, createdAt: Date? = nil,
        updatedAt: Date? = nil, needsSync: Bool = false,
        syncConflict: Bool = false
    ) {
        self.id = id
        self.projectId = projectId
        self.roomId = roomId
        self.assetTemplateId = assetTemplateId
        self.finishId = finishId
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.markupPct = markupPct
        self.status = status
        self.notes = notes
        self.clientNotes = clientNotes
        self.instructions = instructions
        self.shipTo = shipTo
        self.comShipTo = comShipTo
        self.sourceUrl = sourceUrl
        self.isHidden = isHidden
        self.groupKey = groupKey
        self.rank = rank
        self.isSelected = isSelected
        self.templateName = templateName
        self.templateSku = templateSku
        self.finishName = finishName
        self.finishType = finishType
        self.roomName = roomName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.syncConflict = syncConflict
    }
}

// MARK: - Pending Change Queue

@Model
public final class SDPendingChange {
    @Attribute(.unique) public var id: UUID
    var entityType: String
    var entityId: String?
    var operation: String
    var payload: Data
    var createdAt: Date
    var retryCount: Int

    init(
        id: UUID = UUID(),
        entityType: String,
        entityId: String? = nil,
        operation: String,
        payload: Data,
        createdAt: Date = .now,
        retryCount: Int = 0
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
}

