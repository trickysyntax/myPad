import XCTest
import SwiftData
@testable import MyPadKit

final class SyncRegressionTests: XCTestCase {

    func testSyncChangesEscapesPlusInSinceTimestamp() throws {
        let request = try APIRouter.syncChanges(
            since: "2026-05-25T03:51:37.763097+00:00",
            cursor: nil,
            pageSize: 500
        ).urlRequest(baseURL: URL(string: "https://mypad.susie.cloud")!)

        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertTrue(
            url.contains("since=2026-05-25T03:51:37.763097%2B00:00"),
            "syncChanges must percent-encode + in timezone offsets so the server does not receive a decoded space: \(url)"
        )
    }

    func testSyncEnvelopePersistsEmbeddedProjectAndRoomSpaceCaptures() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let json = """
        {
          "sync_version": 1,
          "mode": "changes",
          "server_time": "2026-05-26T00:00:03Z",
          "snapshot_watermark": null,
          "since": "2026-05-26T00:00:00Z",
          "high_watermark": "2026-05-26T00:00:03Z",
          "next_cursor": null,
          "has_more": false,
          "data": {
            "vendors": [],
            "asset_templates": [],
            "asset_finishes": [],
            "clients": [],
            "projects": [
              {
                "id": "project-capture",
                "name": "Capture Project",
                "client": null,
                "client_id": null,
                "project_type": "Residential",
                "status": "active",
                "budget_total": null,
                "markup_pct": null,
                "timeline_start": null,
                "timeline_target": null,
                "notes": null,
                "cover_photo_url": null,
                "space_capture": {
                  "id": "project-capture-1",
                  "scope": "project",
                  "project_id": "project-capture",
                  "room_id": null,
                  "usdz_url": "/uploads/space_captures/project.usdz",
                  "captured_room_json_url": "/uploads/space_captures/project.json",
                  "thumbnail_url": null,
                  "metadata": {},
                  "captured_at": "2026-05-26T00:00:01Z",
                  "created_at": "2026-05-26T00:00:01Z",
                  "updated_at": "2026-05-26T00:00:01Z"
                },
                "is_archived": false,
                "room_count": 1,
                "selection_count": 0,
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-05-26T00:00:02Z"
              }
            ],
            "rooms": [
              {
                "id": "room-capture",
                "project_id": "project-capture",
                "name": "Living Room",
                "sort_order": 0,
                "floor_plan_url": null,
                "photo_urls": [],
                "space_capture": {
                  "id": "room-capture-1",
                  "scope": "room",
                  "project_id": "project-capture",
                  "room_id": "room-capture",
                  "usdz_url": "/uploads/space_captures/room.usdz",
                  "captured_room_json_url": null,
                  "thumbnail_url": "/uploads/space_captures/room.png",
                  "metadata": {},
                  "captured_at": "2026-05-26T00:00:02Z",
                  "created_at": "2026-05-26T00:00:02Z",
                  "updated_at": "2026-05-26T00:00:02Z"
                },
                "notes": null,
                "selection_count": 0,
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-05-26T00:00:02Z"
              }
            ],
            "selections": [],
            "selection_finishes": []
          },
          "tombstones": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(SyncEnvelope.self, from: json)
        XCTAssertEqual(envelope.data.projects.first?.spaceCapture?.id, "project-capture-1")
        XCTAssertEqual(envelope.data.rooms.first?.spaceCapture?.id, "room-capture-1")

        try SyncEngine.applySyncEnvelopeForTesting(envelope, in: context)
        try context.save()

        let projects = try context.fetch(FetchDescriptor<SDProject>())
        XCTAssertEqual(projects.first?.spaceCaptureId, "project-capture-1")
        XCTAssertEqual(projects.first?.spaceCaptureUsdzUrl, "/uploads/space_captures/project.usdz")
        XCTAssertEqual(projects.first?.spaceCaptureCapturedRoomJsonUrl, "/uploads/space_captures/project.json")

        let rooms = try context.fetch(FetchDescriptor<SDRoom>())
        XCTAssertEqual(rooms.first?.spaceCaptureId, "room-capture-1")
        XCTAssertEqual(rooms.first?.spaceCaptureUsdzUrl, "/uploads/space_captures/room.usdz")
        XCTAssertEqual(rooms.first?.spaceCaptureThumbnailUrl, "/uploads/space_captures/room.png")
    }

    func testSyncEnvelopePersistsRoomlessSelections() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let envelope = SyncEnvelope(
            syncVersion: 1,
            mode: "bootstrap",
            serverTime: "2026-05-25T03:51:37Z",
            snapshotWatermark: "2026-05-25T03:51:37Z",
            since: nil,
            highWatermark: "2026-05-25T03:51:37Z",
            nextCursor: nil,
            hasMore: false,
            data: SyncPayload(
                vendors: [],
                assetTemplates: [],
                assetFinishes: [],
                clients: [],
                projects: [],
                rooms: [],
                selections: [roomlessSelection],
                selectionFinishes: [syncSelectionFinish]
            ),
            tombstones: []
        )

        try SyncEngine.applySyncEnvelopeForTesting(envelope, in: context)
        try context.save()

        let selections = try context.fetch(FetchDescriptor<SDSelection>())
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.id, "sel-roomless")
        XCTAssertNil(selections.first?.roomId)
        XCTAssertNil(selections.first?.roomName)
        XCTAssertEqual(selections.first?.projectId, "project-1")
        XCTAssertEqual(selections.first?.templateName, "Legacy Roomless Asset")

        let selectionFinishes = try context.fetch(FetchDescriptor<SDSelectionFinish>())
        XCTAssertEqual(selectionFinishes.count, 1)
        XCTAssertEqual(selectionFinishes.first?.id, "selection-finish-1")
        XCTAssertEqual(selectionFinishes.first?.selectionId, "sel-roomless")
        XCTAssertEqual(selectionFinishes.first?.name, "COM Nailhead")
        XCTAssertEqual(selectionFinishes.first?.shipTo, "Workroom")
    }

    private var roomlessSelection: SelectionDetail {
        SelectionDetail(
            id: "sel-roomless",
            projectId: "project-1",
            roomId: nil,
            assetTemplateId: "asset-1",
            finishId: nil,
            quantity: 1,
            unitPrice: 1250,
            markupPct: nil,
            status: "proposed",
            notes: "Legacy selection without a room",
            clientNotes: nil,
            instructions: nil,
            shipTo: nil,
            comShipTo: nil,
            sourceUrl: nil,
            attachments: nil,
            isHidden: false,
            groupKey: nil,
            rank: nil,
            isSelected: false,
            template: TemplateRef(
                id: "asset-1",
                name: "Legacy Roomless Asset",
                sku: "LRA-1",
                vendor: nil,
                category: nil,
                dimensions: nil,
                leadTimeWeeks: nil,
                specSheetUrl: nil,
                imageUrls: nil
            ),
            finish: nil,
            finishes: nil,
            room: nil,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-05-25T03:51:37Z"
        )
    }

    private var syncSelectionFinish: SelectionFinish {
        SelectionFinish(
            id: "selection-finish-1",
            selectionId: "sel-roomless",
            assetFinishId: "asset-finish-1",
            assetTemplateId: "asset-1",
            name: "COM Nailhead",
            finishType: "trim",
            source: "Designer Library",
            vendor: "Finish Vendor",
            patternColor: "Antique Brass",
            grade: "A",
            width: nil,
            repeat: nil,
            railroad: nil,
            yardage: "3",
            netPrice: "12.00",
            markup: "20%",
            salePrice: "14.40",
            shipTo: "Workroom",
            photoUrl: nil,
            swatchImageUrl: nil,
            imageUrls: ["https://example.com/finish.jpg"],
            isSelected: true,
            sortOrder: 0,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-05-25T03:51:37Z"
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            SDVendor.self,
            SDAssetTemplate.self,
            SDAssetFinish.self,
            SDSelectionFinish.self,
            SDClient.self,
            SDProject.self,
            SDRoom.self,
            SDSelection.self,
            SDPendingChange.self,
            SDSyncState.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
