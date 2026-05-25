import Foundation

// MARK: - Server Configuration

/// Default server URL — configurable via UserDefaults.
public enum ServerConfig {
    public static let baseURLKey = "mypad.serverURL"

    public static var baseURL: URL {
        if let str = UserDefaults.standard.string(forKey: baseURLKey),
           let url = URL(string: str) {
            return url
        }
        return URL(string: "https://mypad.susie.cloud")!
    }
}

// MARK: - API Client

public actor APIClient {
    public static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let authManager: AuthManager

    private var baseURL: URL {
        ServerConfig.baseURL
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.authManager = AuthManager.shared
    }

    private func requestFailureBody(request: URLRequest, statusCode: Int, data: Data) -> String {
        let method = request.httpMethod ?? "HTTP"
        let url = request.url?.absoluteString ?? "<unknown URL>"
        let responseBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 response body>"
        return "\(method) \(url) failed with HTTP \(statusCode): \(responseBody)"
    }

    // MARK: - Request execution

    /// Core request method. Attaches auth header if available.
    /// On 401, attempts token refresh and retries once.
    private func perform<T: Decodable>(
        _ router: APIRouter,
        body: (any Encodable)? = nil
    ) async throws -> T {
        var request = try router.urlRequest(baseURL: baseURL)

        // Attach auth token if available
        if let token = await authManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        // Encode body for write methods
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await execute(request, router: router)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                // Try to extract server error message
                if let serverError = try? decoder.decode(ServerError.self, from: data) {
                    throw APIError.serverMessage(serverError.detail ?? serverError.message ?? "Unknown error")
                }
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        case 409:
            throw APIError.conflict
        default:
            throw APIError.httpError(statusCode: http.statusCode, body: requestFailureBody(request: request, statusCode: http.statusCode, data: data))
        }
    }

    /// Perform a request that returns no body (204 / simple JSON)
    private func performVoid(
        _ router: APIRouter,
        body: (any Encodable)? = nil
    ) async throws {
        var request = try router.urlRequest(baseURL: baseURL)

        if let token = await authManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await execute(request, router: router)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode == 409 { throw APIError.conflict }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, body: requestFailureBody(request: request, statusCode: http.statusCode, data: data))
        }
    }

    // MARK: - Auth

    public func login(username: String, password: String) async throws -> AuthTokens {
        let body = LoginRequest(username: username, password: password)
        let tokens: AuthTokens = try await perform(.login, body: body)
        await authManager.saveTokens(tokens)
        return tokens
    }

    public func logout() async {
        await authManager.clearTokens()
    }

    var isAuthenticated: Bool {
        get async { await authManager.hasToken }
    }

    // MARK: - Vendors

    public func listVendors(
        q: String? = nil,
        tag: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> PaginatedResponse<VendorSummary> {
        try await perform(.listVendors(q: q, tag: tag, limit: limit, offset: offset))
    }

    public func getVendor(id: String) async throws -> VendorDetail {
        try await perform(.getVendor(id: id))
    }

    public func createVendor(
        name: String,
        website: String? = nil,
        category: String? = nil,
        tags: [String]? = nil,
        prose: String? = nil,
        logoUrl: String? = nil
    ) async throws -> VendorSummary {
        var body: [String: Any] = ["name": name]
        if let v = website { body["website"] = v }
        if let v = category { body["category"] = v }
        if let v = tags { body["tags"] = v }
        if let v = prose { body["prose"] = v }
        if let v = logoUrl { body["logo_url"] = v }
        return try await performDict(.createVendor, dict: body)
    }

    public func updateVendor(
        id: String,
        name: String? = nil,
        website: String? = nil,
        category: String? = nil,
        pricingTier: String? = nil,
        knownFor: String? = nil,
        address: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        socials: String? = nil,
        prose: String? = nil,
        tags: [String]? = nil,
        logoUrl: String? = nil,
        clearLogo: Bool = false
    ) async throws -> VendorDetail {
        var body: [String: Any] = [:]
        if let v = name { body["name"] = v }
        if let v = website { body["website"] = v }
        if let v = category { body["category"] = v }
        if let v = pricingTier { body["pricing_tier"] = v }
        if let v = knownFor { body["known_for"] = v }
        if let v = address { body["address"] = v }
        if let v = email { body["email"] = v }
        if let v = phone { body["phone"] = v }
        if let v = socials { body["socials"] = v }
        if let v = prose { body["prose"] = v }
        if let v = tags { body["tags"] = v }
        if clearLogo {
            body["logo_url"] = NSNull()
        } else if let v = logoUrl {
            body["logo_url"] = v
        }
        return try await performDict(.updateVendor(id: id), dict: body)
    }

    // MARK: - Assets

    public func listAssets(
        q: String? = nil,
        vendorId: String? = nil,
        category: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> PaginatedResponse<AssetTemplateSummary> {
        try await perform(.listAssets(q: q, vendorId: vendorId, category: category, limit: limit, offset: offset))
    }

    public func getAsset(id: String) async throws -> AssetTemplateDetail {
        try await perform(.getAsset(id: id))
    }

    public func updateAsset(
        id: String,
        imageUrls: [String]? = nil,
        name: String? = nil,
        sku: String? = nil,
        category: String? = nil,
        description: String? = nil,
        msrp: Double? = nil,
        tradePrice: Double? = nil
    ) async throws -> AssetTemplateDetail {
        var body: [String: Any] = [:]
        if let v = imageUrls { body["image_urls"] = v }
        if let v = name { body["name"] = v }
        if let v = sku { body["sku"] = v }
        if let v = category { body["category"] = v }
        if let v = description { body["description"] = v }
        if let v = msrp { body["msrp"] = v }
        if let v = tradePrice { body["trade_price"] = v }
        return try await performDict(.updateAsset(id: id), dict: body)
    }

    public func getFinishes(assetId: String) async throws -> [AssetFinishSummary] {
        try await perform(.getFinishes(assetId: assetId))
    }

    public func createFinish(
        assetId: String,
        name: String,
        finishType: String = "finish",
        source: String? = nil,
        vendor: String? = nil,
        patternColor: String? = nil,
        grade: String? = nil,
        width: String? = nil,
        repeatValue: String? = nil,
        railroad: Bool? = nil,
        yardage: String? = nil,
        netPrice: String? = nil,
        markup: String? = nil,
        salePrice: String? = nil,
        shipTo: String? = nil,
        photoUrl: String? = nil,
        swatchImageUrl: String? = nil,
        imageUrls: [String]? = nil,
        upchargePct: Double? = nil,
        inStock: Bool? = nil,
        sortOrder: Int? = nil
    ) async throws -> AssetFinishSummary {
        let body = finishBody(
            name: name,
            finishType: finishType,
            source: source,
            vendor: vendor,
            patternColor: patternColor,
            grade: grade,
            width: width,
            repeatValue: repeatValue,
            railroad: railroad,
            yardage: yardage,
            netPrice: netPrice,
            markup: markup,
            salePrice: salePrice,
            shipTo: shipTo,
            photoUrl: photoUrl,
            swatchImageUrl: swatchImageUrl,
            imageUrls: imageUrls,
            upchargePct: upchargePct,
            inStock: inStock,
            sortOrder: sortOrder
        )
        return try await performDict(.createFinish(assetId: assetId), dict: body)
    }

    public func updateFinish(assetId: String, finishId: String, fields: [String: Any]) async throws -> AssetFinishSummary {
        try await performDict(.updateFinish(assetId: assetId, finishId: finishId), dict: fields)
    }

    public func deleteFinish(assetId: String, finishId: String) async throws {
        try await performVoid(.deleteFinish(assetId: assetId, finishId: finishId))
    }

    public func reorderFinishes(assetId: String, order: [String]) async throws -> [AssetFinishSummary] {
        let response: AssetFinishListResponse = try await performDict(.reorderFinishes(assetId: assetId), dict: ["order": order])
        return response.data
    }

    public func createAsset(
        name: String,
        vendorId: String? = nil,
        sku: String? = nil,
        category: String? = nil,
        description: String? = nil,
        msrp: Double? = nil,
        tradePrice: Double? = nil,
        leadTimeWeeks: Int? = nil,
        minimumOrder: String? = nil,
        dimensions: String? = nil,
        careInstructions: String? = nil,
        imageUrls: [String]? = nil,
        specSheetUrl: String? = nil,
        isDiscontinued: Bool = false
    ) async throws -> AssetTemplateDetail {
        var body: [String: Any] = ["name": name]
        if let v = vendorId { body["vendor_id"] = v }
        if let v = sku { body["sku"] = v }
        if let v = category { body["category"] = v }
        if let v = description { body["description"] = v }
        if let v = msrp { body["msrp"] = v }
        if let v = tradePrice { body["trade_price"] = v }
        if let v = leadTimeWeeks { body["lead_time_weeks"] = v }
        if let v = minimumOrder { body["minimum_order"] = v }
        if let v = dimensions { body["dimensions"] = v }
        if let v = careInstructions { body["care_instructions"] = v }
        if let v = imageUrls { body["image_urls"] = v }
        if let v = specSheetUrl { body["spec_sheet_url"] = v }
        if isDiscontinued { body["is_discontinued"] = true }
        return try await performDict(.createAsset, dict: body)
    }

    // MARK: - Clients

    public func listClients(
        q: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> PaginatedResponse<ClientSummary> {
        try await perform(.listClients(q: q, limit: limit, offset: offset))
    }

    public func getClient(id: String) async throws -> ClientDetail {
        try await perform(.getClient(id: id))
    }

    public func createClient(
        name: String,
        email: String? = nil,
        phone: String? = nil,
        billingAddress: String? = nil,
        siteAddress: String? = nil,
        notes: String? = nil
    ) async throws -> ClientDetail {
        let body: [String: String?] = [
            "name": name,
            "email": email,
            "phone": phone,
            "billing_address": billingAddress,
            "site_address": siteAddress,
            "notes": notes,
        ]
        return try await perform(.createClient, body: body.compactMapValues { $0 })
    }

    public func updateClient(
        id: String,
        name: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        billingAddress: String? = nil,
        siteAddress: String? = nil,
        notes: String? = nil
    ) async throws -> ClientDetail {
        var body: [String: String] = [:]
        if let v = name { body["name"] = v }
        if let v = email { body["email"] = v }
        if let v = phone { body["phone"] = v }
        if let v = billingAddress { body["billing_address"] = v }
        if let v = siteAddress { body["site_address"] = v }
        if let v = notes { body["notes"] = v }
        return try await perform(.updateClient(id: id), body: body)
    }

    // MARK: - Projects

    public func listProjects(
        q: String? = nil,
        clientId: String? = nil,
        status: String? = nil,
        includeArchived: Bool = false,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> PaginatedResponse<ProjectSummary> {
        try await perform(.listProjects(
            q: q, clientId: clientId, status: status,
            includeArchived: includeArchived, limit: limit, offset: offset
        ))
    }

    public func getProject(id: String) async throws -> ProjectDetail {
        try await perform(.getProject(id: id))
    }

    public func createProject(
        name: String,
        clientId: String? = nil,
        projectType: String? = nil,
        timelineTarget: String? = nil,
        notes: String? = nil,
        markupPct: Double? = nil,
        coverPhotoUrl: String? = nil
    ) async throws -> ProjectDetail {
        var body: [String: Any] = ["name": name]
        if let v = clientId { body["client_id"] = v }
        if let v = projectType { body["project_type"] = v }
        if let v = timelineTarget { body["timeline_target"] = v }
        if let v = notes { body["notes"] = v }
        if let v = markupPct { body["markup_pct"] = v }
        if let v = coverPhotoUrl { body["cover_photo_url"] = v }
        // Use dictionary encoding via JSONSerialization for mixed types
        return try await performDict(.createProject, dict: body)
    }

    public func updateProject(
        id: String,
        name: String? = nil,
        clientId: String? = nil,
        projectType: String? = nil,
        status: String? = nil,
        budgetTotal: Double? = nil,
        markupPct: Double? = nil,
        timelineStart: String? = nil,
        timelineTarget: String? = nil,
        notes: String? = nil,
        isArchived: Bool? = nil,
        coverPhotoUrl: String? = nil,
        clearCoverPhoto: Bool = false
    ) async throws -> ProjectDetail {
        var body: [String: Any] = [:]
        if let v = name { body["name"] = v }
        if let v = clientId { body["client_id"] = v }
        if let v = projectType { body["project_type"] = v }
        if let v = status { body["status"] = v }
        if let v = budgetTotal { body["budget_total"] = v }
        if let v = markupPct { body["markup_pct"] = v }
        if let v = timelineStart { body["timeline_start"] = v }
        if let v = timelineTarget { body["timeline_target"] = v }
        if let v = notes { body["notes"] = v }
        if let v = isArchived { body["is_archived"] = v }
        if clearCoverPhoto {
            body["cover_photo_url"] = NSNull()
        } else if let v = coverPhotoUrl {
            body["cover_photo_url"] = v
        }
        return try await performDict(.updateProject(id: id), dict: body)
    }

    public func archiveProject(id: String) async throws -> ArchiveResponse {
        try await perform(.archiveProject(id: id))
    }

    // MARK: - Rooms

    public func listRooms(projectId: String) async throws -> [RoomDetail] {
        try await perform(.listRooms(projectId: projectId))
    }

    public func getRoom(projectId: String, roomId: String) async throws -> RoomDetail {
        try await perform(.getRoom(projectId: projectId, roomId: roomId))
    }

    public func createRoom(
        projectId: String,
        name: String,
        notes: String? = nil
    ) async throws -> RoomDetail {
        var body: [String: String] = ["name": name]
        if let v = notes { body["notes"] = v }
        return try await perform(.createRoom(projectId: projectId), body: body)
    }

    public func updateRoom(
        projectId: String,
        roomId: String,
        name: String? = nil,
        notes: String? = nil,
        sortOrder: Int? = nil,
        photoUrls: [String]? = nil
    ) async throws -> RoomDetail {
        var body: [String: Any] = [:]
        if let v = name { body["name"] = v }
        if let v = notes { body["notes"] = v }
        if let v = sortOrder { body["sort_order"] = v }
        if let v = photoUrls { body["photo_urls"] = v }
        return try await performDict(.updateRoom(projectId: projectId, roomId: roomId), dict: body)
    }

    public func deleteRoom(projectId: String, roomId: String) async throws {
        try await performVoid(.deleteRoom(projectId: projectId, roomId: roomId))
    }

    public func reorderRooms(projectId: String, roomIds: [String]) async throws -> [RoomDetail] {
        let body = ["room_ids": roomIds]
        return try await perform(.reorderRooms(projectId: projectId), body: body)
    }

    // MARK: - Selections

    public func listSelections(
        projectId: String,
        roomId: String,
        status: String? = nil
    ) async throws -> [SelectionDetail] {
        let response: SelectionListResponse = try await perform(
            .listSelections(projectId: projectId, roomId: roomId, status: status)
        )
        return response.data
    }

    public func createSelection(
        projectId: String,
        roomId: String,
        assetTemplateId: String,
        finishId: String? = nil,
        finishIds: [String]? = nil,
        copyFinishes: Bool? = nil,
        finishes: [[String: Any]]? = nil,
        quantity: Int = 1,
        unitPrice: Double? = nil,
        notes: String? = nil,
        groupKey: String? = nil,
        rank: Int? = nil,
        attachments: [String]? = nil,
        sourceUrl: String? = nil
    ) async throws -> SelectionDetail {
        var body: [String: Any] = [
            "asset_template_id": assetTemplateId,
            "quantity": quantity,
        ]
        if let v = finishId { body["finish_id"] = v }
        if let v = finishIds { body["finish_ids"] = v }
        if let v = copyFinishes { body["copy_finishes"] = v }
        if let v = finishes { body["finishes"] = v }
        if let v = unitPrice { body["unit_price"] = v }
        if let v = notes { body["notes"] = v }
        if let v = groupKey { body["group_key"] = v }
        if let v = rank { body["rank"] = v }
        if let v = attachments { body["attachments"] = v }
        if let v = sourceUrl { body["source_url"] = v }
        return try await performDict(.createSelection(projectId: projectId, roomId: roomId), dict: body)
    }

    public func updateSelection(
        projectId: String,
        roomId: String,
        selectionId: String,
        quantity: Int? = nil,
        unitPrice: Double? = nil,
        markupPct: Double? = nil,
        notes: String? = nil,
        clientNotes: String? = nil,
        instructions: String? = nil,
        shipTo: String? = nil,
        comShipTo: String? = nil,
        sourceUrl: String? = nil,
        isHidden: Bool? = nil,
        groupKey: String? = nil,
        rank: Int? = nil,
        isSelected: Bool? = nil,
        attachments: [String]? = nil
    ) async throws -> SelectionDetail {
        var body: [String: Any] = [:]
        if let v = quantity { body["quantity"] = v }
        if let v = unitPrice { body["unit_price"] = v }
        if let v = markupPct { body["markup_pct"] = v }
        if let v = notes { body["notes"] = v }
        if let v = clientNotes { body["client_notes"] = v }
        if let v = instructions { body["instructions"] = v }
        if let v = shipTo { body["ship_to"] = v }
        if let v = comShipTo { body["com_ship_to"] = v }
        if let v = sourceUrl { body["source_url"] = v }
        if let v = isHidden { body["is_hidden"] = v }
        if let v = groupKey { body["group_key"] = v }
        if let v = rank { body["rank"] = v }
        if let v = isSelected { body["is_selected"] = v }
        if let v = attachments { body["attachments"] = v }
        return try await performDict(
            .updateSelection(projectId: projectId, roomId: roomId, selectionId: selectionId),
            dict: body
        )
    }

    public func updateSelectionStatus(
        projectId: String,
        roomId: String,
        selectionId: String,
        status: String
    ) async throws -> SelectionDetail {
        let body = ["status": status]
        return try await perform(
            .updateSelectionStatus(projectId: projectId, roomId: roomId, selectionId: selectionId),
            body: body
        )
    }

    public func deleteSelection(
        projectId: String,
        roomId: String,
        selectionId: String
    ) async throws {
        try await performVoid(.deleteSelection(projectId: projectId, roomId: roomId, selectionId: selectionId))
    }

    public func listSelectionFinishes(projectId: String, roomId: String, selectionId: String) async throws -> [SelectionFinish] {
        let response: SelectionFinishListResponse = try await perform(
            .listSelectionFinishes(projectId: projectId, roomId: roomId, selectionId: selectionId)
        )
        return response.data
    }

    public func createSelectionFinish(
        projectId: String,
        roomId: String,
        selectionId: String,
        fields: [String: Any]
    ) async throws -> [SelectionFinish] {
        let response: SelectionFinishListResponse = try await performDict(
            .createSelectionFinish(projectId: projectId, roomId: roomId, selectionId: selectionId),
            dict: fields
        )
        return response.data
    }

    public func updateSelectionFinish(
        projectId: String,
        roomId: String,
        selectionId: String,
        finishId: String,
        fields: [String: Any]
    ) async throws -> SelectionFinish {
        try await performDict(
            .updateSelectionFinish(projectId: projectId, roomId: roomId, selectionId: selectionId, finishId: finishId),
            dict: fields
        )
    }

    public func deleteSelectionFinish(projectId: String, roomId: String, selectionId: String, finishId: String) async throws {
        try await performVoid(.deleteSelectionFinish(projectId: projectId, roomId: roomId, selectionId: selectionId, finishId: finishId))
    }

    public func reorderSelectionFinishes(projectId: String, roomId: String, selectionId: String, order: [String]) async throws -> [SelectionFinish] {
        let response: SelectionFinishListResponse = try await performDict(
            .reorderSelectionFinishes(projectId: projectId, roomId: roomId, selectionId: selectionId),
            dict: ["order": order]
        )
        return response.data
    }

    // MARK: - Sync

    public func syncBootstrap(
        cursor: String? = nil,
        pageSize: Int = 500,
        includeArchived: Bool = true,
        includeDiscontinued: Bool = true
    ) async throws -> SyncEnvelope {
        try await perform(.syncBootstrap(
            cursor: cursor,
            pageSize: pageSize,
            includeArchived: includeArchived,
            includeDiscontinued: includeDiscontinued
        ))
    }

    public func syncChanges(
        since: String,
        cursor: String? = nil,
        pageSize: Int = 500
    ) async throws -> SyncEnvelope {
        try await perform(.syncChanges(since: since, cursor: cursor, pageSize: pageSize))
    }

    // MARK: - Budget

    public func getBudget(
        projectId: String,
        roomId: String? = nil,
        includeHidden: Bool = false
    ) async throws -> BudgetResponse {
        try await perform(.getBudget(projectId: projectId, roomId: roomId, includeHidden: includeHidden))
    }

    // MARK: - Upload

    public func uploadImage(data: Data, filename: String) async throws -> UploadResponse {
        var request = try APIRouter.upload.urlRequest(baseURL: baseURL)

        if let token = await authManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await execute(request, router: .upload)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(UploadResponse.self, from: responseData)
    }
    // MARK: - Helpers

    /// Perform a request with a dictionary body (for mixed-type payloads)
    private func performDict<T: Decodable>(
        _ router: APIRouter,
        dict: [String: Any]
    ) async throws -> T {
        var request = try router.urlRequest(baseURL: baseURL)

        if let token = await authManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: dict)

        let (data, response) = try await execute(request, router: router)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                if let serverError = try? decoder.decode(ServerError.self, from: data) {
                    throw APIError.serverMessage(serverError.detail ?? serverError.message ?? "Unknown error")
                }
                throw APIError.decodingError(error)
            }
        case 401: throw APIError.unauthorized
        case 409: throw APIError.conflict
        default:
            throw APIError.httpError(statusCode: http.statusCode, body: requestFailureBody(request: request, statusCode: http.statusCode, data: data))
        }
    }

    private func finishBody(
        name: String? = nil,
        finishType: String? = nil,
        source: String? = nil,
        vendor: String? = nil,
        patternColor: String? = nil,
        grade: String? = nil,
        width: String? = nil,
        repeatValue: String? = nil,
        railroad: Bool? = nil,
        yardage: String? = nil,
        netPrice: String? = nil,
        markup: String? = nil,
        salePrice: String? = nil,
        shipTo: String? = nil,
        photoUrl: String? = nil,
        swatchImageUrl: String? = nil,
        imageUrls: [String]? = nil,
        upchargePct: Double? = nil,
        inStock: Bool? = nil,
        sortOrder: Int? = nil
    ) -> [String: Any] {
        var body: [String: Any] = [:]
        if let v = name { body["name"] = v }
        if let v = finishType { body["finish_type"] = v }
        if let v = source { body["source"] = v }
        if let v = vendor { body["vendor"] = v }
        if let v = patternColor { body["pattern_color"] = v }
        if let v = grade { body["grade"] = v }
        if let v = width { body["width"] = v }
        if let v = repeatValue { body["repeat"] = v }
        if let v = railroad { body["railroad"] = v }
        if let v = yardage { body["yardage"] = v }
        if let v = netPrice { body["net_price"] = v }
        if let v = markup { body["markup"] = v }
        if let v = salePrice { body["sale_price"] = v }
        if let v = shipTo { body["ship_to"] = v }
        if let v = photoUrl { body["photo_url"] = v }
        if let v = swatchImageUrl { body["swatch_image_url"] = v }
        if let v = imageUrls { body["image_urls"] = v }
        if let v = upchargePct { body["upcharge_pct"] = v }
        if let v = inStock { body["in_stock"] = v }
        if let v = sortOrder { body["sort_order"] = v }
        return body
    }

    private func execute(_ request: URLRequest, router: APIRouter) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            let url = request.url?.absoluteString ?? router.path
            throw APIError.transportError(method: router.method, url: url, underlying: error)
        }
    }
}

// MARK: - Supporting Types

/// Type-erased Encodable wrapper for the perform method
private struct AnyEncodable: Encodable {
    let value: any Encodable

    init(_ value: any Encodable) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

/// Generic server error shape
private struct ServerError: Decodable {
    let detail: String?
    let message: String?
}