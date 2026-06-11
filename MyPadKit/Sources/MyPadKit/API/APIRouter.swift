import Foundation

/// Builds URLRequests for every API endpoint. No network — just URL construction.
public enum APIRouter {
    // Auth
    case login
    case refreshToken

    // Vendors
    case listVendors(q: String?, tag: String?, limit: Int, offset: Int)
    case getVendor(id: String)
    case createVendor
    case updateVendor(id: String)

    // Assets
    case listAssets(q: String?, vendorId: String?, category: String?, limit: Int, offset: Int)
    case getAsset(id: String)
    case createAsset
    case updateAsset(id: String)
    case deleteAsset(id: String)
    case getFinishes(assetId: String)
    case createFinish(assetId: String)
    case updateFinish(assetId: String, finishId: String)
    case deleteFinish(assetId: String, finishId: String)
    case reorderFinishes(assetId: String)

    // Clients
    case listClients(q: String?, limit: Int, offset: Int)
    case getClient(id: String)
    case createClient
    case updateClient(id: String)

    // Projects
    case listProjects(q: String?, clientId: String?, status: String?, includeArchived: Bool, limit: Int, offset: Int)
    case getProject(id: String)
    case createProject
    case updateProject(id: String)
    case archiveProject(id: String)

    // Rooms
    case listRooms(projectId: String)
    case getRoom(projectId: String, roomId: String)
    case createRoom(projectId: String)
    case updateRoom(projectId: String, roomId: String)
    case deleteRoom(projectId: String, roomId: String)
    case reorderRooms(projectId: String)

    // Selections
    case listSelections(projectId: String, roomId: String, status: String?)
    case getSelection(projectId: String, roomId: String, selectionId: String)
    case createSelection(projectId: String, roomId: String)
    case updateSelection(projectId: String, roomId: String, selectionId: String)
    case deleteSelection(projectId: String, roomId: String, selectionId: String)
    case updateSelectionStatus(projectId: String, roomId: String, selectionId: String)
    case listSelectionFinishes(projectId: String, roomId: String, selectionId: String)
    case createSelectionFinish(projectId: String, roomId: String, selectionId: String)
    case updateSelectionFinish(projectId: String, roomId: String, selectionId: String, finishId: String)
    case deleteSelectionFinish(projectId: String, roomId: String, selectionId: String, finishId: String)
    case reorderSelectionFinishes(projectId: String, roomId: String, selectionId: String)

    // Budget
    case getBudget(projectId: String, roomId: String?, includeHidden: Bool)

    // Upload
    case upload

    // Space Captures
    case uploadProjectSpaceCapture(projectId: String)
    case deleteProjectSpaceCapture(projectId: String)
    case uploadRoomSpaceCapture(projectId: String, roomId: String)
    case deleteRoomSpaceCapture(projectId: String, roomId: String)
    case getSpaceCapture(id: String)

    // Sync
    case syncBootstrap(cursor: String?, pageSize: Int, includeArchived: Bool, includeDiscontinued: Bool)
    case syncChanges(since: String, cursor: String?, pageSize: Int)

    // MARK: - Path

    var path: String {
        switch self {
        case .login:                       return "/api/auth/login"
        case .refreshToken:                return "/api/auth/refresh"
        case .listVendors, .getVendor:     return "" // handled in url()
        case .createVendor:                return "/api/vendors"
        case .updateVendor(let id):        return "/api/vendors/\(id)"
        case .listAssets, .createAsset:    return "/api/assets"
        case .getAsset(let id),
             .updateAsset(let id),
             .deleteAsset(let id):         return "/api/assets/\(id)"
        case .getFinishes(let aid),
             .createFinish(let aid):       return "/api/assets/\(aid)/finishes"
        case .updateFinish(let aid, let fid),
             .deleteFinish(let aid, let fid): return "/api/assets/\(aid)/finishes/\(fid)"
        case .reorderFinishes(let aid):      return "/api/assets/\(aid)/finishes/reorder"
        case .listClients, .createClient:  return "/api/clients"
        case .getClient(let id),
             .updateClient(let id):        return "/api/clients/\(id)"
        case .listProjects, .createProject: return "/api/projects"
        case .getProject(let id),
             .updateProject(let id):       return "/api/projects/\(id)"
        case .archiveProject(let id):      return "/api/projects/\(id)/archive"
        case .listRooms(let pid),
             .createRoom(let pid):         return "/api/projects/\(pid)/rooms"
        case .getRoom(let pid, let rid),
             .updateRoom(let pid, let rid),
             .deleteRoom(let pid, let rid): return "/api/projects/\(pid)/rooms/\(rid)"
        case .reorderRooms(let pid):       return "/api/projects/\(pid)/rooms/reorder"
        case .listSelections(let pid, let rid, _),
             .createSelection(let pid, let rid): return "/api/projects/\(pid)/rooms/\(rid)/selections"
        case .getSelection(let pid, let rid, let sid),
             .updateSelection(let pid, let rid, let sid),
             .deleteSelection(let pid, let rid, let sid): return "/api/projects/\(pid)/rooms/\(rid)/selections/\(sid)"
        case .updateSelectionStatus(let pid, let rid, let sid): return "/api/projects/\(pid)/rooms/\(rid)/selections/\(sid)/status"
        case .listSelectionFinishes(let pid, let rid, let sid),
             .createSelectionFinish(let pid, let rid, let sid): return "/api/projects/\(pid)/rooms/\(rid)/selections/\(sid)/finishes"
        case .updateSelectionFinish(let pid, let rid, let sid, let fid),
             .deleteSelectionFinish(let pid, let rid, let sid, let fid): return "/api/projects/\(pid)/rooms/\(rid)/selections/\(sid)/finishes/\(fid)"
        case .reorderSelectionFinishes(let pid, let rid, let sid): return "/api/projects/\(pid)/rooms/\(rid)/selections/\(sid)/finishes/reorder"
        case .getBudget(let pid, _, _):    return "/api/projects/\(pid)/budget"
        case .upload:                      return "/api/uploads"
        case .uploadProjectSpaceCapture(let pid),
             .deleteProjectSpaceCapture(let pid): return "/api/projects/\(pid)/space-capture"
        case .uploadRoomSpaceCapture(let pid, let rid),
             .deleteRoomSpaceCapture(let pid, let rid): return "/api/projects/\(pid)/rooms/\(rid)/space-capture"
        case .getSpaceCapture(let id):     return "/api/space-captures/\(id)"
        case .syncBootstrap:               return "/api/sync/bootstrap"
        case .syncChanges:                 return "/api/sync/changes"
        }
    }

    // MARK: - HTTP Method

    var method: String {
        switch self {
        case .login, .refreshToken, .createVendor, .createAsset, .createFinish,
             .createClient, .createProject, .createRoom, .createSelection,
             .createSelectionFinish, .archiveProject, .upload,
             .uploadProjectSpaceCapture, .uploadRoomSpaceCapture:
            return "POST"
        case .updateVendor, .updateAsset, .updateFinish, .updateClient,
             .updateProject, .updateRoom, .updateSelection, .updateSelectionFinish,
             .reorderFinishes, .reorderSelectionFinishes:
            return "PUT"
        case .deleteAsset, .deleteFinish, .deleteRoom, .deleteSelection, .deleteSelectionFinish,
             .deleteProjectSpaceCapture, .deleteRoomSpaceCapture:
            return "DELETE"
        case .updateSelectionStatus:
            return "PATCH"
        case .reorderRooms:
            return "PUT"
        default:
            return "GET"
        }
    }

    // MARK: - Query Items

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        switch self {
        case .listVendors(let q, let tag, let limit, let offset):
            if let q = q, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
            if let tag = tag, !tag.isEmpty { items.append(URLQueryItem(name: "tag", value: tag)) }
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))

        case .listAssets(let q, let vid, let cat, let limit, let offset):
            if let q = q, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
            if let vid = vid { items.append(URLQueryItem(name: "vendor_id", value: vid)) }
            if let cat = cat { items.append(URLQueryItem(name: "category", value: cat)) }
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))

        case .listClients(let q, let limit, let offset):
            if let q = q, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))

        case .listProjects(let q, let cid, let status, let archived, let limit, let offset):
            if let q = q, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
            if let cid = cid { items.append(URLQueryItem(name: "client_id", value: cid)) }
            if let status = status { items.append(URLQueryItem(name: "status", value: status)) }
            if archived { items.append(URLQueryItem(name: "include_archived", value: "true")) }
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))

        case .listSelections(_, _, let status):
            if let status = status { items.append(URLQueryItem(name: "status", value: status)) }

        case .getBudget(_, let roomId, let includeHidden):
            if let roomId = roomId { items.append(URLQueryItem(name: "room_id", value: roomId)) }
            if includeHidden { items.append(URLQueryItem(name: "include_hidden", value: "true")) }

        case .syncBootstrap(let cursor, let pageSize, let includeArchived, let includeDiscontinued):
            if let cursor, !cursor.isEmpty { items.append(URLQueryItem(name: "cursor", value: cursor)) }
            items.append(URLQueryItem(name: "page_size", value: String(pageSize)))
            items.append(URLQueryItem(name: "include_archived", value: includeArchived ? "true" : "false"))
            items.append(URLQueryItem(name: "include_discontinued", value: includeDiscontinued ? "true" : "false"))

        case .syncChanges(let since, let cursor, let pageSize):
            items.append(URLQueryItem(name: "since", value: since))
            if let cursor, !cursor.isEmpty { items.append(URLQueryItem(name: "cursor", value: cursor)) }
            items.append(URLQueryItem(name: "page_size", value: String(pageSize)))

        default:
            break
        }
        return items
    }

    // Special case: vendor list has a different path pattern
    private var vendorPath: String {
        switch self {
        case .listVendors:  return "/api/vendors"
        case .getVendor(let id): return "/api/vendors/\(id)"
        default: return ""
        }
    }

    // MARK: - Build URLRequest

    func urlRequest(baseURL: URL) throws -> URLRequest {
        let resolvedPath: String
        if !vendorPath.isEmpty {
            resolvedPath = vendorPath
        } else {
            resolvedPath = path
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(resolvedPath), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        let items = queryItems
        if !items.isEmpty {
            components.queryItems = items
            // URLComponents leaves `+` unescaped in query item values, but many
            // servers/form decoders interpret `+` as a space. Sync watermarks
            // commonly include `+00:00` timezone offsets, so force those plus
            // signs through as `%2B` before building the final request URL.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
