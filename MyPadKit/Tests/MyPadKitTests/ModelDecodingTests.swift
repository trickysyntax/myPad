import XCTest
@testable import MyPadKit

final class ModelDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - PaginatedResponse

    func testDecodePaginatedVendors() throws {
        let json = """
        {
            "total": 960,
            "limit": 50,
            "offset": 0,
            "data": [
                {
                    "id": "abc-123",
                    "slug": "restoration-hardware",
                    "name": "Restoration Hardware",
                    "category": "Furniture",
                    "pricingTier": "$$$$",
                    "tags": ["furniture", "lighting"],
                    "website": "https://rh.com"
                }
            ]
        }
        """.data(using: .utf8)!

        let result = try decoder.decode(PaginatedResponse<VendorSummary>.self, from: json)
        XCTAssertEqual(result.total, 960)
        XCTAssertEqual(result.data.count, 1)
        XCTAssertEqual(result.data[0].name, "Restoration Hardware")
        XCTAssertEqual(result.data[0].pricingTier, "$$$$")
    }

    // MARK: - VendorDetail

    func testDecodeVendorDetail() throws {
        let json = """
        {
            "id": "abc-123",
            "slug": "restoration-hardware",
            "name": "Restoration Hardware",
            "category": "Furniture",
            "pricingTier": "$$$$",
            "pricingDetail": "Premium luxury",
            "targetMarket": "High-end residential",
            "creditTerms": "Net 30",
            "knownFor": "Cloud Sofa",
            "leadership": "Gary Friedman",
            "website": "https://rh.com",
            "address": "15 Koch Rd, Corte Madera, CA",
            "email": "trade@rh.com",
            "phone": "800-762-1005",
            "socials": "@restorationhardware",
            "prose": "Luxury home furnishings brand.",
            "tags": ["furniture", "lighting"],
            "sources": ["https://rh.com/about"]
        }
        """.data(using: .utf8)!

        let vendor = try decoder.decode(VendorDetail.self, from: json)
        XCTAssertEqual(vendor.name, "Restoration Hardware")
        XCTAssertEqual(vendor.knownFor, "Cloud Sofa")
        XCTAssertEqual(vendor.tags?.count, 2)
    }

    // MARK: - SelectionDetail

    func testDecodeSelection() throws {
        let json = """
        {
            "id": "sel-1",
            "projectId": "proj-1",
            "roomId": "room-1",
            "assetTemplateId": "tmpl-1",
            "finishId": "fin-1",
            "quantity": 2,
            "unitPrice": 4200.00,
            "markupPct": 20.0,
            "status": "proposed",
            "notes": "Client prefers deeper seat",
            "clientNotes": null,
            "instructions": null,
            "shipTo": "White Glove",
            "comShipTo": null,
            "sourceUrl": null,
            "isHidden": false,
            "groupKey": "sofa-options",
            "rank": 1,
            "isSelected": true,
            "template": {
                "id": "tmpl-1",
                "name": "Cloud Sofa",
                "sku": "RH-CS-2024"
            },
            "finish": {
                "id": "fin-1",
                "name": "Performance Weave, Oatmeal",
                "finishType": "weave"
            },
            "room": {
                "id": "room-1",
                "name": "Living Room"
            },
            "createdAt": "2026-01-15T10:30:00Z",
            "updatedAt": "2026-03-01T14:00:00Z"
        }
        """.data(using: .utf8)!

        let selection = try decoder.decode(SelectionDetail.self, from: json)
        XCTAssertEqual(selection.status, "proposed")
        XCTAssertEqual(selection.quantity, 2)
        XCTAssertEqual(selection.unitPrice, 4200.0)
        XCTAssertEqual(selection.template?.name, "Cloud Sofa")
        XCTAssertEqual(selection.finish?.finishType, "weave")
        XCTAssertTrue(selection.isSelected)
        XCTAssertEqual(selection.groupKey, "sofa-options")
    }

    // MARK: - SyncEnvelope

    func testDecodeSyncEnvelope() throws {
        let json = """
        {
            "sync_version": 1,
            "mode": "bootstrap",
            "server_time": "2026-05-24T20:05:01Z",
            "snapshot_watermark": "2026-05-24T20:05:01Z",
            "next_cursor": null,
            "has_more": false,
            "data": {
                "vendors": [
                    {
                        "id": "vendor-1",
                        "slug": "4spaces",
                        "name": "4Spaces",
                        "category": "Textiles",
                        "pricing_tier": "$$$$",
                        "pricing_detail": "Premium",
                        "target_market": "Residential",
                        "credit_terms": "Net 30",
                        "known_for": "Textiles",
                        "leadership": "Founder",
                        "website": "https://example.com",
                        "logo_url": null,
                        "address": null,
                        "email": null,
                        "phone": null,
                        "socials": null,
                        "prose": "Curated vendor brief.",
                        "tags": ["Textiles"],
                        "sources": ["brief"],
                        "is_active": true,
                        "created_at": "2026-01-01T00:00:00Z",
                        "updated_at": "2026-05-24T20:00:00Z"
                    }
                ],
                "asset_templates": [],
                "asset_finishes": [],
                "clients": [
                    {
                        "id": "client-1",
                        "name": "Smith",
                        "email": "smith@example.com",
                        "phone": null,
                        "billing_address": null,
                        "site_address": null,
                        "notes": null,
                        "project_count": 1,
                        "created_at": "2026-01-01T00:00:00Z",
                        "updated_at": "2026-05-24T20:00:00Z"
                    }
                ],
                "projects": [
                    {
                        "id": "project-1",
                        "name": "Smith Residence",
                        "client": { "id": "client-1", "name": "Smith" },
                        "client_id": "client-1",
                        "project_type": "Residential",
                        "status": "active",
                        "budget_total": 100000.0,
                        "markup_pct": 20.0,
                        "timeline_start": null,
                        "timeline_target": null,
                        "notes": null,
                        "cover_photo_url": null,
                        "is_archived": false,
                        "room_count": 1,
                        "selection_count": 0,
                        "created_at": "2026-01-01T00:00:00Z",
                        "updated_at": "2026-05-24T20:00:00Z"
                    }
                ],
                "rooms": [],
                "selections": []
            },
            "tombstones": [
                {
                    "entity_type": "selection",
                    "entity_id": "selection-1",
                    "deleted_at": "2026-05-24T20:04:00Z"
                }
            ]
        }
        """.data(using: .utf8)!

        let envelope = try decoder.decode(SyncEnvelope.self, from: json)
        XCTAssertEqual(envelope.syncVersion, 1)
        XCTAssertFalse(envelope.hasMore)
        XCTAssertEqual(envelope.data.vendors.first?.updatedAt, "2026-05-24T20:00:00Z")
        XCTAssertEqual(envelope.data.clients.first?.projectCount, 1)
        XCTAssertEqual(envelope.data.projects.first?.clientId, "client-1")
        XCTAssertEqual(envelope.tombstones.first?.entityType, "selection")
    }

    // MARK: - BudgetResponse

    func testDecodeBudget() throws {
        let json = """
        {
            "projectId": "proj-1",
            "projectName": "Smith Residence",
            "budgetTotalEntered": 150000.0,
            "rooms": [
                {
                    "roomId": "room-1",
                    "roomName": "Living Room",
                    "selectionCount": 8,
                    "subtotal": 45200.0,
                    "markupTotal": 6780.0,
                    "roomTotal": 51980.0,
                    "statusBreakdown": {
                        "proposed": 3,
                        "client_approved": 3,
                        "ordered": 2
                    }
                }
            ],
            "grandTotal": 142800.0,
            "grandMarkup": 20100.0,
            "vsBudgetPct": 95.2,
            "statusBreakdown": {
                "proposed": 8,
                "client_approved": 5,
                "ordered": 6,
                "delivered": 3,
                "installed": 2
            }
        }
        """.data(using: .utf8)!

        let budget = try decoder.decode(BudgetResponse.self, from: json)
        XCTAssertEqual(budget.grandTotal, 142800.0)
        XCTAssertEqual(budget.vsBudgetPct, 95.2)
        XCTAssertEqual(budget.rooms.count, 1)
        XCTAssertEqual(budget.rooms[0].roomName, "Living Room")
        XCTAssertEqual(budget.statusBreakdown?["installed"], 2)
    }
}
