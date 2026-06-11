import Foundation
import SwiftData
import Network
import Observation
import OSLog

// MARK: - Sync Engine

/// Coordinates pull (API → SwiftData) and push (local changes → API) operations.
/// Read path is always local-first; API calls are background updates.
@MainActor
@Observable
public final class SyncEngine {
    public static let shared = SyncEngine()

    private nonisolated static let logger = Logger(subsystem: "org.ciderhouse.myPad", category: "sync")
    private static let lastSyncDefaultsKey = "mypad.sync.lastSuccessfulFullSyncAt"

    private let api = APIClient.shared
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "mypad.sync.monitor")

    public private(set) var isSyncing = false
    public private(set) var isOnline = true
    public private(set) var lastSyncAt: Date?
    public private(set) var syncError: String?

    private var modelContainer: ModelContainer?

    private init() {
        lastSyncAt = UserDefaults.standard.object(forKey: Self.lastSyncDefaultsKey) as? Date

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let online = path.status == .satisfied
                let wasOffline = self?.isOnline == false
                self?.isOnline = online
                if online && wasOffline {
                    self?.processPendingChanges()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func hasFreshSync(maxAge: TimeInterval) -> Bool {
        guard let lastSyncAt else { return false }
        return Date().timeIntervalSince(lastSyncAt) < maxAge
    }

    // MARK: - Full Sync (Pull)

    public func fullSync() async {
        guard !isSyncing else { return }
        guard let modelContainer else {
            syncError = "ModelContainer not configured"
            return
        }

        isSyncing = true
        syncError = nil
        let syncStartedAt = Date()
        Self.logger.info("fullSync started")

        do {
            try await Task.detached(priority: .utility) {
                try await Self.runFullSync(modelContainer: modelContainer)
            }.value

            lastSyncAt = Date()
            UserDefaults.standard.set(lastSyncAt, forKey: Self.lastSyncDefaultsKey)
            syncError = nil
            Self.logger.info("fullSync finished in \(Date().timeIntervalSince(syncStartedAt), format: .fixed(precision: 2), privacy: .public)s")
        } catch {
            let message = Self.describeError(error)
            syncError = message
            Self.logger.error("fullSync failed after \(Date().timeIntervalSince(syncStartedAt), format: .fixed(precision: 2), privacy: .public)s: \(message, privacy: .public)")
        }

        isSyncing = false
    }

    private nonisolated static func runFullSync(modelContainer: ModelContainer) async throws {
        let ctx = ModelContext(modelContainer)
        ctx.autosaveEnabled = false

        let api = APIClient.shared
        let state = try syncState(in: ctx)
        let pageSize = 500

        if let completedCursor = state.completedCursor, !completedCursor.isEmpty {
            try await runChangesSync(since: completedCursor, api: api, state: state, pageSize: pageSize, in: ctx)
        } else {
            try await runBootstrapSync(api: api, state: state, pageSize: pageSize, in: ctx)
        }
    }

    private nonisolated static func runBootstrapSync(
        api: APIClient,
        state: SDSyncState,
        pageSize: Int,
        in ctx: ModelContext
    ) async throws {
        var cursor: String?
        var pageCount = 0
        var completedCursor: String?
        let started = Date()

        repeat {
            let pageCursor = cursor
            let envelope = try await timedPhase("syncBootstrap", detail: "page \(pageCount + 1)") {
                try await api.syncBootstrap(cursor: pageCursor, pageSize: pageSize)
            }
            pageCount += 1

            try timedPhase("apply.bootstrap", detail: "page \(pageCount)") {
                try applySyncEnvelope(envelope, in: ctx)
                completedCursor = envelope.highWatermark ?? envelope.snapshotWatermark ?? envelope.serverTime
                if !envelope.hasMore {
                    state.completedCursor = completedCursor
                    state.completedHighWatermark = envelope.highWatermark ?? envelope.snapshotWatermark
                    state.lastBootstrapAt = .now
                    state.updatedAt = .now
                }
                try saveIfNeeded(ctx, phase: "bootstrap page \(pageCount)")
            }

            guard envelope.hasMore else { break }
            guard let next = envelope.nextCursor, !next.isEmpty else {
                throw SyncEngineError.missingNextCursor(mode: "bootstrap")
            }
            cursor = next
        } while true

        logger.info("bootstrap sync completed \(pageCount, privacy: .public) pages in \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
    }

    private nonisolated static func runChangesSync(
        since: String,
        api: APIClient,
        state: SDSyncState,
        pageSize: Int,
        in ctx: ModelContext
    ) async throws {
        var cursor: String?
        var pageCount = 0
        var completedCursor = since
        let started = Date()

        repeat {
            let pageCursor = cursor
            let envelope = try await timedPhase("syncChanges", detail: "page \(pageCount + 1)") {
                try await api.syncChanges(since: since, cursor: pageCursor, pageSize: pageSize)
            }
            pageCount += 1

            try timedPhase("apply.changes", detail: "page \(pageCount)") {
                try applySyncEnvelope(envelope, in: ctx)
                completedCursor = envelope.highWatermark ?? completedCursor
                if !envelope.hasMore {
                    state.completedCursor = completedCursor
                    state.completedHighWatermark = envelope.highWatermark ?? completedCursor
                    state.lastChangesAt = .now
                    state.updatedAt = .now
                }
                try saveIfNeeded(ctx, phase: "changes page \(pageCount)")
            }

            guard envelope.hasMore else { break }
            guard let next = envelope.nextCursor, !next.isEmpty else {
                throw SyncEngineError.missingNextCursor(mode: "changes")
            }
            cursor = next
        } while true

        logger.info("changes sync completed \(pageCount, privacy: .public) pages in \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
    }

    // MARK: - Pull Helpers

    /// Generic pagination helper — fetches all pages until `data.count < limit`.
    private nonisolated static func pullAllPaginated<T>(
        fetcher: (Int) async throws -> PaginatedResponse<T>
    ) async throws -> [T] {
        var all: [T] = []
        var offset = 0
        let limit = 100

        while true {
            let page = try await fetcher(offset)
            all.append(contentsOf: page.data)
            if page.data.count < limit { break }
            offset += limit
        }

        return all
    }

    private nonisolated static func timedPhase<T>(
        _ phase: String,
        detail: String? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        let started = Date()
        if let detail {
            logger.debug("phase \(phase, privacy: .public) started (\(detail, privacy: .public))")
        } else {
            logger.debug("phase \(phase, privacy: .public) started")
        }
        do {
            let result = try await operation()
            if let detail {
                logger.info("phase \(phase, privacy: .public) finished (\(detail, privacy: .public)) in \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
            } else {
                logger.info("phase \(phase, privacy: .public) finished in \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
            }
            return result
        } catch {
            let message = describeError(error)
            if let detail {
                logger.error("phase \(phase, privacy: .public) failed (\(detail, privacy: .public)) after \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s: \(message, privacy: .public)")
            } else {
                logger.error("phase \(phase, privacy: .public) failed after \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s: \(message, privacy: .public)")
            }
            throw error
        }
    }

    private nonisolated static func timedPhase<T>(
        _ phase: String,
        detail: String? = nil,
        operation: () throws -> T
    ) throws -> T {
        let started = Date()
        if let detail {
            logger.debug("phase \(phase, privacy: .public) started (\(detail, privacy: .public))")
        } else {
            logger.debug("phase \(phase, privacy: .public) started")
        }
        do {
            let result = try operation()
            if let detail {
                logger.info("phase \(phase, privacy: .public) finished (\(detail, privacy: .public)) in \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
            } else {
                logger.info("phase \(phase, privacy: .public) finished in \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
            }
            return result
        } catch {
            let message = describeError(error)
            if let detail {
                logger.error("phase \(phase, privacy: .public) failed (\(detail, privacy: .public)) after \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s: \(message, privacy: .public)")
            } else {
                logger.error("phase \(phase, privacy: .public) failed after \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s: \(message, privacy: .public)")
            }
            throw error
        }
    }

    private nonisolated static func describeError(_ error: Error) -> String {
        let localized = error.localizedDescription
        let reflected = String(reflecting: error)
        if reflected == localized || reflected.isEmpty {
            return localized
        }
        return "\(localized) [\(reflected)]"
    }

    private nonisolated static func saveIfNeeded(_ ctx: ModelContext, phase: String) throws {
        guard ctx.hasChanges else { return }
        let started = Date()
        try ctx.save()
        logger.info("phase save.\(phase, privacy: .public) finished in \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
    }

    private nonisolated static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }

    private nonisolated static func syncState(in ctx: ModelContext) throws -> SDSyncState {
        let existing = try ctx.fetch(FetchDescriptor<SDSyncState>()).first
        if let existing { return existing }
        let state = SDSyncState()
        ctx.insert(state)
        return state
    }

    private nonisolated static func applySyncEnvelope(_ envelope: SyncEnvelope, in ctx: ModelContext) throws {
        try upsertSyncVendors(envelope.data.vendors, in: ctx)
        try upsertAssets(envelope.data.assetTemplates, in: ctx)
        try upsertSyncFinishes(envelope.data.assetFinishes, in: ctx)
        try upsertSyncClients(envelope.data.clients, in: ctx)
        try upsertSyncProjects(envelope.data.projects, in: ctx)
        try upsertSyncRooms(envelope.data.rooms, in: ctx)
        try upsertSyncSelections(envelope.data.selections, in: ctx)
        let selectionFinishesById = Dictionary(
            grouping: envelope.data.selectionFinishes + envelope.data.selections.flatMap { $0.finishes ?? [] },
            by: { $0.id }
        ).compactMap { $0.value.last }
        try upsertSyncSelectionFinishes(selectionFinishesById, in: ctx)
        try applyTombstones(envelope.tombstones, in: ctx)
    }

    nonisolated static func applySyncEnvelopeForTesting(_ envelope: SyncEnvelope, in ctx: ModelContext) throws {
        try applySyncEnvelope(envelope, in: ctx)
    }

    // MARK: - Upsert Helpers

    private nonisolated static func upsertSyncVendors(_ vendors: [SyncVendor], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDVendor>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for vendor in vendors {
            let createdAt = parseDate(vendor.createdAt)
            let updatedAt = parseDate(vendor.updatedAt)
            if let sd = existingById[vendor.id] {
                sd.slug = vendor.slug
                sd.name = vendor.name
                sd.category = vendor.category
                sd.pricingTier = vendor.pricingTier
                sd.pricingDetail = vendor.pricingDetail
                sd.targetMarket = vendor.targetMarket
                sd.creditTerms = vendor.creditTerms
                sd.knownFor = vendor.knownFor
                sd.leadership = vendor.leadership
                sd.website = vendor.website
                sd.address = vendor.address
                sd.email = vendor.email
                sd.phone = vendor.phone
                sd.socials = vendor.socials
                sd.prose = vendor.prose
                sd.tags = vendor.tags ?? []
                sd.sources = vendor.sources ?? []
                sd.isActive = vendor.isActive
                sd.createdAt = createdAt
                sd.updatedAt = updatedAt
                sd.lastSyncedAt = .now
            } else {
                let sd = SDVendor(
                    id: vendor.id,
                    slug: vendor.slug,
                    name: vendor.name,
                    category: vendor.category,
                    pricingTier: vendor.pricingTier,
                    pricingDetail: vendor.pricingDetail,
                    targetMarket: vendor.targetMarket,
                    creditTerms: vendor.creditTerms,
                    knownFor: vendor.knownFor,
                    leadership: vendor.leadership,
                    website: vendor.website,
                    address: vendor.address,
                    email: vendor.email,
                    phone: vendor.phone,
                    socials: vendor.socials,
                    prose: vendor.prose,
                    tags: vendor.tags ?? [],
                    sources: vendor.sources ?? [],
                    isActive: vendor.isActive,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                ctx.insert(sd)
                existingById[vendor.id] = sd
            }
        }
    }

    private nonisolated static func upsertVendors(_ vendors: [VendorSummary], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDVendor>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for vendor in vendors {
            if let sd = existingById[vendor.id] {
                // Full sync only has summary fields. Preserve detail-only fields such as prose,
                // knownFor, targetMarket, pricingDetail, and leadership.
                sd.slug = vendor.slug
                sd.name = vendor.name
                sd.category = vendor.category
                sd.pricingTier = vendor.pricingTier
                sd.website = vendor.website
                sd.tags = vendor.tags ?? []
                sd.lastSyncedAt = .now
            } else {
                let sd = SDVendor(
                    id: vendor.id, slug: vendor.slug, name: vendor.name,
                    category: vendor.category, pricingTier: vendor.pricingTier,
                    website: vendor.website, tags: vendor.tags ?? []
                )
                ctx.insert(sd)
                existingById[vendor.id] = sd
            }
        }
    }

    private nonisolated static func upsertClients(_ clients: [ClientSummary], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDClient>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for client in clients {
            if let sd = existingById[client.id] {
                sd.name = client.name
                sd.email = client.email
                sd.phone = client.phone
                sd.projectCount = client.projectCount
                sd.lastSyncedAt = .now
            } else {
                let sd = SDClient(
                    id: client.id, name: client.name,
                    email: client.email, phone: client.phone,
                    projectCount: client.projectCount
                )
                ctx.insert(sd)
                existingById[client.id] = sd
            }
        }
    }

    private nonisolated static func upsertAssets(_ assets: [AssetTemplateSummary], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDAssetTemplate>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for asset in assets {
            if let sd = existingById[asset.id] {
                sd.vendorId = asset.vendorId
                sd.vendorName = asset.vendor?.name
                sd.name = asset.name
                sd.sku = asset.sku
                sd.category = asset.category
                sd.descriptionText = asset.description
                sd.msrp = asset.msrp
                sd.tradePrice = asset.tradePrice
                sd.leadTimeWeeks = asset.leadTimeWeeks
                sd.minimumOrder = asset.minimumOrder
                sd.dimensions = asset.dimensions
                sd.careInstructions = asset.careInstructions
                sd.imageUrls = asset.imageUrls ?? []
                sd.specSheetUrl = asset.specSheetUrl
                sd.isDiscontinued = asset.isDiscontinued
                sd.finishCount = asset.finishCount
                sd.lastSyncedAt = .now
            } else {
                let sd = SDAssetTemplate(
                    id: asset.id, vendorId: asset.vendorId,
                    vendorName: asset.vendor?.name, name: asset.name,
                    sku: asset.sku, category: asset.category,
                    descriptionText: asset.description,
                    msrp: asset.msrp, tradePrice: asset.tradePrice,
                    leadTimeWeeks: asset.leadTimeWeeks,
                    minimumOrder: asset.minimumOrder,
                    dimensions: asset.dimensions,
                    careInstructions: asset.careInstructions,
                    imageUrls: asset.imageUrls ?? [],
                    specSheetUrl: asset.specSheetUrl,
                    isDiscontinued: asset.isDiscontinued,
                    finishCount: asset.finishCount
                )
                ctx.insert(sd)
                existingById[asset.id] = sd
            }
        }
    }

    private nonisolated static func upsertProjects(_ projects: [ProjectSummary], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDProject>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for project in projects {
            if let sd = existingById[project.id] {
                sd.name = project.name
                sd.clientName = project.clientName
                sd.projectType = project.projectType
                sd.status = project.status
                sd.budgetTotal = project.budgetTotal
                sd.roomCount = project.roomCount
                sd.selectionCount = project.selectionCount
                sd.spaceCaptureId = project.spaceCapture?.id
                sd.spaceCaptureUsdzUrl = project.spaceCapture?.usdzUrl
                sd.spaceCaptureCapturedRoomJsonUrl = project.spaceCapture?.capturedRoomJsonUrl
                sd.spaceCaptureThumbnailUrl = project.spaceCapture?.thumbnailUrl
                sd.spaceCaptureCapturedAt = parseDate(project.spaceCapture?.capturedAt)
                sd.isArchived = project.isArchived
                sd.lastSyncedAt = .now
            } else {
                let sd = SDProject(
                    id: project.id, name: project.name,
                    clientName: project.clientName,
                    projectType: project.projectType,
                    status: project.status,
                    budgetTotal: project.budgetTotal,
                    spaceCaptureId: project.spaceCapture?.id,
                    spaceCaptureUsdzUrl: project.spaceCapture?.usdzUrl,
                    spaceCaptureCapturedRoomJsonUrl: project.spaceCapture?.capturedRoomJsonUrl,
                    spaceCaptureThumbnailUrl: project.spaceCapture?.thumbnailUrl,
                    spaceCaptureCapturedAt: parseDate(project.spaceCapture?.capturedAt),
                    isArchived: project.isArchived,
                    roomCount: project.roomCount,
                    selectionCount: project.selectionCount
                )
                ctx.insert(sd)
                existingById[project.id] = sd
            }
        }
    }

    private nonisolated static func fetchExistingRoomsById(in ctx: ModelContext) throws -> [String: SDRoom] {
        let existing = try ctx.fetch(FetchDescriptor<SDRoom>())
        return Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
    }

    private nonisolated static func fetchExistingSelectionsById(in ctx: ModelContext) throws -> [String: SDSelection] {
        let existing = try ctx.fetch(FetchDescriptor<SDSelection>())
        return Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
    }

    private nonisolated static func upsertRooms(
        _ rooms: [RoomDetail],
        projectId: String,
        in ctx: ModelContext,
        existingById: inout [String: SDRoom]
    ) throws {
        let formatter = ISO8601DateFormatter()

        for room in rooms {
            if let sd = existingById[room.id] {
                sd.projectId = projectId
                sd.name = room.name
                sd.sortOrder = room.sortOrder
                sd.floorPlanUrl = room.floorPlanUrl
                sd.photoUrls = room.photoUrls ?? []
                sd.spaceCaptureId = room.spaceCapture?.id
                sd.spaceCaptureUsdzUrl = room.spaceCapture?.usdzUrl
                sd.spaceCaptureCapturedRoomJsonUrl = room.spaceCapture?.capturedRoomJsonUrl
                sd.spaceCaptureThumbnailUrl = room.spaceCapture?.thumbnailUrl
                sd.spaceCaptureCapturedAt = parseDate(room.spaceCapture?.capturedAt)
                sd.notes = room.notes
                sd.selectionCount = room.selectionCount
                sd.updatedAt = room.updatedAt.flatMap { formatter.date(from: $0) }
            } else {
                let sd = SDRoom(
                    id: room.id, projectId: projectId, name: room.name,
                    sortOrder: room.sortOrder,
                    floorPlanUrl: room.floorPlanUrl,
                    photoUrls: room.photoUrls ?? [],
                    spaceCaptureId: room.spaceCapture?.id,
                    spaceCaptureUsdzUrl: room.spaceCapture?.usdzUrl,
                    spaceCaptureCapturedRoomJsonUrl: room.spaceCapture?.capturedRoomJsonUrl,
                    spaceCaptureThumbnailUrl: room.spaceCapture?.thumbnailUrl,
                    spaceCaptureCapturedAt: parseDate(room.spaceCapture?.capturedAt),
                    notes: room.notes,
                    selectionCount: room.selectionCount
                )
                ctx.insert(sd)
                existingById[room.id] = sd
            }
        }
    }

    private nonisolated static func upsertSelections(
        _ selections: [SelectionDetail],
        projectId: String,
        roomId: String,
        in ctx: ModelContext,
        existingById: inout [String: SDSelection],
        dateFormatter: ISO8601DateFormatter
    ) throws {
        for sel in selections {
            if let sd = existingById[sel.id] {
                sd.projectId = projectId
                sd.roomId = roomId
                sd.assetTemplateId = sel.assetTemplateId
                sd.finishId = sel.finishId
                sd.quantity = sel.quantity
                sd.unitPrice = sel.unitPrice
                sd.markupPct = sel.markupPct
                sd.status = sel.status
                sd.notes = sel.notes
                sd.clientNotes = sel.clientNotes
                sd.instructions = sel.instructions
                sd.shipTo = sel.shipTo
                sd.comShipTo = sel.comShipTo
                sd.sourceUrl = sel.sourceUrl
                sd.isHidden = sel.isHidden
                sd.groupKey = sel.groupKey
                sd.rank = sel.rank
                sd.isSelected = sel.isSelected
                sd.templateName = sel.template?.name
                sd.templateSku = sel.template?.sku
                sd.finishName = sel.finish?.name
                sd.finishType = sel.finish?.finishType
                sd.roomName = sel.room?.name
                sd.updatedAt = sel.updatedAt.flatMap { dateFormatter.date(from: $0) }
                sd.needsSync = false
                sd.syncConflict = false
            } else {
                let sd = SDSelection(
                    id: sel.id, projectId: projectId, roomId: roomId,
                    assetTemplateId: sel.assetTemplateId,
                    finishId: sel.finishId,
                    quantity: sel.quantity, unitPrice: sel.unitPrice,
                    markupPct: sel.markupPct, status: sel.status,
                    notes: sel.notes, clientNotes: sel.clientNotes,
                    instructions: sel.instructions,
                    shipTo: sel.shipTo, comShipTo: sel.comShipTo,
                    sourceUrl: sel.sourceUrl,
                    isHidden: sel.isHidden,
                    groupKey: sel.groupKey, rank: sel.rank,
                    isSelected: sel.isSelected,
                    templateName: sel.template?.name,
                    templateSku: sel.template?.sku,
                    finishName: sel.finish?.name,
                    finishType: sel.finish?.finishType,
                    roomName: sel.room?.name,
                    updatedAt: sel.updatedAt.flatMap { dateFormatter.date(from: $0) }
                )
                ctx.insert(sd)
                existingById[sel.id] = sd
            }
        }
    }

    private nonisolated static func upsertSyncFinishes(_ finishes: [AssetFinishSummary], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDAssetFinish>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for finish in finishes {
            let createdAt = parseDate(finish.createdAt)
            let updatedAt = parseDate(finish.updatedAt)
            if let sd = existingById[finish.id] {
                sd.assetTemplateId = finish.assetTemplateId
                sd.name = finish.name
                sd.finishType = finish.finishType
                sd.upchargePct = finish.upchargePct
                sd.grade = finish.grade
                sd.width = finish.width
                sd.repeatText = finish.repeat
                sd.railroad = finish.railroad
                sd.source = finish.source
                sd.vendor = finish.vendor
                sd.patternColor = finish.patternColor
                sd.yardage = finish.yardage
                sd.netPrice = finish.netPrice
                sd.markup = finish.markup
                sd.salePrice = finish.salePrice
                sd.shipTo = finish.shipTo
                sd.photoUrl = finish.photoUrl
                sd.inStock = finish.inStock
                sd.swatchImageUrl = finish.swatchImageUrl
                sd.imageUrls = finish.imageUrls ?? []
                sd.sortOrder = finish.sortOrder
                sd.createdAt = createdAt
                sd.updatedAt = updatedAt
            } else {
                let sd = SDAssetFinish(
                    id: finish.id,
                    assetTemplateId: finish.assetTemplateId,
                    name: finish.name,
                    finishType: finish.finishType,
                    upchargePct: finish.upchargePct,
                    grade: finish.grade,
                    width: finish.width,
                    repeatText: finish.repeat,
                    railroad: finish.railroad,
                    source: finish.source,
                    vendor: finish.vendor,
                    patternColor: finish.patternColor,
                    yardage: finish.yardage,
                    netPrice: finish.netPrice,
                    markup: finish.markup,
                    salePrice: finish.salePrice,
                    shipTo: finish.shipTo,
                    photoUrl: finish.photoUrl,
                    inStock: finish.inStock,
                    swatchImageUrl: finish.swatchImageUrl,
                    imageUrls: finish.imageUrls ?? [],
                    sortOrder: finish.sortOrder,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                ctx.insert(sd)
                existingById[finish.id] = sd
            }
        }
    }

    private nonisolated static func upsertSyncSelectionFinishes(_ finishes: [SelectionFinish], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDSelectionFinish>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for finish in finishes {
            let createdAt = parseDate(finish.createdAt)
            let updatedAt = parseDate(finish.updatedAt)
            if let sd = existingById[finish.id] {
                sd.selectionId = finish.selectionId
                sd.assetFinishId = finish.assetFinishId
                sd.assetTemplateId = finish.assetTemplateId
                sd.name = finish.name
                sd.finishType = finish.finishType
                sd.source = finish.source
                sd.vendor = finish.vendor
                sd.patternColor = finish.patternColor
                sd.grade = finish.grade
                sd.width = finish.width
                sd.repeatText = finish.repeat
                sd.railroad = finish.railroad
                sd.yardage = finish.yardage
                sd.netPrice = finish.netPrice
                sd.markup = finish.markup
                sd.salePrice = finish.salePrice
                sd.shipTo = finish.shipTo
                sd.photoUrl = finish.photoUrl
                sd.swatchImageUrl = finish.swatchImageUrl
                sd.imageUrls = finish.imageUrls ?? []
                sd.isSelected = finish.isSelected
                sd.sortOrder = finish.sortOrder ?? 0
                sd.createdAt = createdAt
                sd.updatedAt = updatedAt
            } else {
                let sd = SDSelectionFinish(
                    id: finish.id,
                    selectionId: finish.selectionId,
                    assetFinishId: finish.assetFinishId,
                    assetTemplateId: finish.assetTemplateId,
                    name: finish.name,
                    finishType: finish.finishType,
                    source: finish.source,
                    vendor: finish.vendor,
                    patternColor: finish.patternColor,
                    grade: finish.grade,
                    width: finish.width,
                    repeatText: finish.repeat,
                    railroad: finish.railroad,
                    yardage: finish.yardage,
                    netPrice: finish.netPrice,
                    markup: finish.markup,
                    salePrice: finish.salePrice,
                    shipTo: finish.shipTo,
                    photoUrl: finish.photoUrl,
                    swatchImageUrl: finish.swatchImageUrl,
                    imageUrls: finish.imageUrls ?? [],
                    isSelected: finish.isSelected,
                    sortOrder: finish.sortOrder ?? 0,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                ctx.insert(sd)
                existingById[finish.id] = sd
            }
        }
    }

    private nonisolated static func upsertSyncClients(_ clients: [SyncClient], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDClient>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for client in clients {
            let createdAt = parseDate(client.createdAt)
            let updatedAt = parseDate(client.updatedAt)
            if let sd = existingById[client.id] {
                sd.name = client.name
                sd.email = client.email
                sd.phone = client.phone
                sd.billingAddress = client.billingAddress
                sd.siteAddress = client.siteAddress
                sd.notes = client.notes
                sd.projectCount = client.projectCount ?? sd.projectCount
                sd.createdAt = createdAt
                sd.updatedAt = updatedAt
                sd.lastSyncedAt = .now
            } else {
                let sd = SDClient(
                    id: client.id,
                    name: client.name,
                    email: client.email,
                    phone: client.phone,
                    billingAddress: client.billingAddress,
                    siteAddress: client.siteAddress,
                    notes: client.notes,
                    projectCount: client.projectCount ?? 0,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                ctx.insert(sd)
                existingById[client.id] = sd
            }
        }
    }

    private nonisolated static func upsertSyncProjects(_ projects: [SyncProject], in ctx: ModelContext) throws {
        let existing = try ctx.fetch(FetchDescriptor<SDProject>())
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for project in projects {
            let createdAt = parseDate(project.createdAt)
            let updatedAt = parseDate(project.updatedAt)
            if let sd = existingById[project.id] {
                sd.name = project.name
                sd.clientId = project.clientId ?? project.client?.id
                sd.clientName = project.client?.name
                sd.projectType = project.projectType
                sd.status = project.status
                sd.budgetTotal = project.budgetTotal
                sd.markupPct = project.markupPct
                sd.timelineStart = parseDate(project.timelineStart)
                sd.timelineTarget = parseDate(project.timelineTarget)
                sd.notes = project.notes
                sd.spaceCaptureId = project.spaceCapture?.id
                sd.spaceCaptureUsdzUrl = project.spaceCapture?.usdzUrl
                sd.spaceCaptureCapturedRoomJsonUrl = project.spaceCapture?.capturedRoomJsonUrl
                sd.spaceCaptureThumbnailUrl = project.spaceCapture?.thumbnailUrl
                sd.spaceCaptureCapturedAt = parseDate(project.spaceCapture?.capturedAt)
                sd.isArchived = project.isArchived
                sd.roomCount = project.roomCount
                sd.selectionCount = project.selectionCount
                sd.createdAt = createdAt
                sd.updatedAt = updatedAt
                sd.lastSyncedAt = .now
            } else {
                let sd = SDProject(
                    id: project.id,
                    name: project.name,
                    clientId: project.clientId ?? project.client?.id,
                    clientName: project.client?.name,
                    projectType: project.projectType,
                    status: project.status,
                    budgetTotal: project.budgetTotal,
                    markupPct: project.markupPct,
                    timelineStart: parseDate(project.timelineStart),
                    timelineTarget: parseDate(project.timelineTarget),
                    notes: project.notes,
                    spaceCaptureId: project.spaceCapture?.id,
                    spaceCaptureUsdzUrl: project.spaceCapture?.usdzUrl,
                    spaceCaptureCapturedRoomJsonUrl: project.spaceCapture?.capturedRoomJsonUrl,
                    spaceCaptureThumbnailUrl: project.spaceCapture?.thumbnailUrl,
                    spaceCaptureCapturedAt: parseDate(project.spaceCapture?.capturedAt),
                    isArchived: project.isArchived,
                    roomCount: project.roomCount,
                    selectionCount: project.selectionCount,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                ctx.insert(sd)
                existingById[project.id] = sd
            }
        }
    }

    private nonisolated static func upsertSyncRooms(_ rooms: [RoomDetail], in ctx: ModelContext) throws {
        var existingById = try fetchExistingRoomsById(in: ctx)
        for room in rooms {
            if let sd = existingById[room.id] {
                sd.projectId = room.projectId
                sd.name = room.name
                sd.sortOrder = room.sortOrder
                sd.floorPlanUrl = room.floorPlanUrl
                sd.photoUrls = room.photoUrls ?? []
                sd.spaceCaptureId = room.spaceCapture?.id
                sd.spaceCaptureUsdzUrl = room.spaceCapture?.usdzUrl
                sd.spaceCaptureCapturedRoomJsonUrl = room.spaceCapture?.capturedRoomJsonUrl
                sd.spaceCaptureThumbnailUrl = room.spaceCapture?.thumbnailUrl
                sd.spaceCaptureCapturedAt = parseDate(room.spaceCapture?.capturedAt)
                sd.notes = room.notes
                sd.selectionCount = room.selectionCount
                sd.createdAt = parseDate(room.createdAt)
                sd.updatedAt = parseDate(room.updatedAt)
            } else {
                let sd = SDRoom(
                    id: room.id,
                    projectId: room.projectId,
                    name: room.name,
                    sortOrder: room.sortOrder,
                    floorPlanUrl: room.floorPlanUrl,
                    photoUrls: room.photoUrls ?? [],
                    spaceCaptureId: room.spaceCapture?.id,
                    spaceCaptureUsdzUrl: room.spaceCapture?.usdzUrl,
                    spaceCaptureCapturedRoomJsonUrl: room.spaceCapture?.capturedRoomJsonUrl,
                    spaceCaptureThumbnailUrl: room.spaceCapture?.thumbnailUrl,
                    spaceCaptureCapturedAt: parseDate(room.spaceCapture?.capturedAt),
                    notes: room.notes,
                    selectionCount: room.selectionCount,
                    createdAt: parseDate(room.createdAt),
                    updatedAt: parseDate(room.updatedAt)
                )
                ctx.insert(sd)
                existingById[room.id] = sd
            }
        }
    }

    private nonisolated static func upsertSyncSelections(_ selections: [SelectionDetail], in ctx: ModelContext) throws {
        var existingById = try fetchExistingSelectionsById(in: ctx)
        for sel in selections {
            if let sd = existingById[sel.id] {
                sd.projectId = sel.projectId
                sd.roomId = sel.roomId
                sd.assetTemplateId = sel.assetTemplateId
                sd.finishId = sel.finishId
                sd.quantity = sel.quantity
                sd.unitPrice = sel.unitPrice
                sd.markupPct = sel.markupPct
                sd.status = sel.status
                sd.notes = sel.notes
                sd.clientNotes = sel.clientNotes
                sd.instructions = sel.instructions
                sd.shipTo = sel.shipTo
                sd.comShipTo = sel.comShipTo
                sd.sourceUrl = sel.sourceUrl
                sd.isHidden = sel.isHidden
                sd.groupKey = sel.groupKey
                sd.rank = sel.rank
                sd.isSelected = sel.isSelected
                sd.templateName = sel.template?.name
                sd.templateSku = sel.template?.sku
                sd.finishName = sel.finish?.name
                sd.finishType = sel.finish?.finishType
                sd.roomName = sel.room?.name
                sd.createdAt = parseDate(sel.createdAt)
                sd.updatedAt = parseDate(sel.updatedAt)
                sd.needsSync = false
                sd.syncConflict = false
            } else {
                let sd = SDSelection(
                    id: sel.id,
                    projectId: sel.projectId,
                    roomId: sel.roomId,
                    assetTemplateId: sel.assetTemplateId,
                    finishId: sel.finishId,
                    quantity: sel.quantity,
                    unitPrice: sel.unitPrice,
                    markupPct: sel.markupPct,
                    status: sel.status,
                    notes: sel.notes,
                    clientNotes: sel.clientNotes,
                    instructions: sel.instructions,
                    shipTo: sel.shipTo,
                    comShipTo: sel.comShipTo,
                    sourceUrl: sel.sourceUrl,
                    isHidden: sel.isHidden,
                    groupKey: sel.groupKey,
                    rank: sel.rank,
                    isSelected: sel.isSelected,
                    templateName: sel.template?.name,
                    templateSku: sel.template?.sku,
                    finishName: sel.finish?.name,
                    finishType: sel.finish?.finishType,
                    roomName: sel.room?.name,
                    createdAt: parseDate(sel.createdAt),
                    updatedAt: parseDate(sel.updatedAt)
                )
                ctx.insert(sd)
                existingById[sel.id] = sd
            }
        }
    }

    private nonisolated static func applyTombstones(_ tombstones: [SyncTombstone], in ctx: ModelContext) throws {
        guard !tombstones.isEmpty else { return }
        let vendors = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDVendor>()).map { ($0.id, $0) })
        let assets = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDAssetTemplate>()).map { ($0.id, $0) })
        let finishes = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDAssetFinish>()).map { ($0.id, $0) })
        let selectionFinishes = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDSelectionFinish>()).map { ($0.id, $0) })
        let clients = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDClient>()).map { ($0.id, $0) })
        let projects = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDProject>()).map { ($0.id, $0) })
        let rooms = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDRoom>()).map { ($0.id, $0) })
        let selections = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<SDSelection>()).map { ($0.id, $0) })

        for tombstone in tombstones {
            switch tombstone.entityType {
            case "vendor": if let row = vendors[tombstone.entityId] { ctx.delete(row) }
            case "asset_template": if let row = assets[tombstone.entityId] { ctx.delete(row) }
            case "asset_finish": if let row = finishes[tombstone.entityId] { ctx.delete(row) }
            case "selection_finish": if let row = selectionFinishes[tombstone.entityId] { ctx.delete(row) }
            case "client": if let row = clients[tombstone.entityId] { ctx.delete(row) }
            case "project": if let row = projects[tombstone.entityId] { ctx.delete(row) }
            case "room": if let row = rooms[tombstone.entityId] { ctx.delete(row) }
            case "selection": if let row = selections[tombstone.entityId] { ctx.delete(row) }
            default:
                logger.warning("unknown tombstone entity type \(tombstone.entityType, privacy: .public)")
            }
        }
    }

    // MARK: - Push (Process Pending Changes)

    func processPendingChanges() {
        guard let modelContainer, isOnline else { return }

        Task.detached(priority: .utility) {
            let ctx = ModelContext(modelContainer)
            ctx.autosaveEnabled = false

            let descriptor = FetchDescriptor<SDPendingChange>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            guard let pending = try? ctx.fetch(descriptor) else { return }

            for change in pending {
                do {
                    try await Self.executeChange(change)
                    ctx.delete(change)
                } catch {
                    change.retryCount += 1
                    if change.retryCount > 5 {
                        // Mark the corresponding entity as conflicted
                        Self.markConflict(entityType: change.entityType, entityId: change.entityId, in: ctx)
                    }
                    // Stop processing on network error, leave remaining in queue
                    if case APIError.networkError = error {
                        break
                    }
                }
            }
            try? Self.saveIfNeeded(ctx, phase: "pending changes")
        }
    }

    private nonisolated static func executeChange(_ change: SDPendingChange) async throws {
        guard let body = try? JSONSerialization.jsonObject(with: change.payload) as? [String: Any] else {
            return
        }

        let api = APIClient.shared
        switch (change.entityType, change.operation) {
        case ("selection", "update"):
            if let pid = body["project_id"] as? String,
               let rid = body["room_id"] as? String,
               let sid = change.entityId {
                // Reconstruct the update call from payload
                _ = try await api.updateSelection(
                    projectId: pid, roomId: rid, selectionId: sid
                )
            }
        case ("selection", "status"):
            if let pid = body["project_id"] as? String,
               let rid = body["room_id"] as? String,
               let sid = change.entityId,
               let status = body["status"] as? String {
                _ = try await api.updateSelectionStatus(
                    projectId: pid, roomId: rid, selectionId: sid, status: status
                )
            }
        default:
            break
        }
    }

    private nonisolated static func markConflict(entityType: String, entityId: String?, in ctx: ModelContext) {
        guard let entityId else { return }

        switch entityType {
        case "selection":
            if let sd = try? ctx.fetch(
                FetchDescriptor<SDSelection>(predicate: #Predicate { $0.id == entityId })
            ).first {
                sd.syncConflict = true
            }
        default:
            break
        }
    }
}

private enum SyncEngineError: LocalizedError {
    case missingNextCursor(mode: String)

    var errorDescription: String? {
        switch self {
        case .missingNextCursor(let mode):
            return "Sync response for \(mode) had hasMore=true but no nextCursor"
        }
    }
}

