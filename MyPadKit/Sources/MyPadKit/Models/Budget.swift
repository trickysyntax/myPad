import Foundation

// MARK: - Budget Room breakdown

public struct BudgetRoom: Codable, Sendable {
    public let roomId: String
    public let roomName: String
    public let selectionCount: Int
    public let subtotal: Double
    public let markupTotal: Double
    public let roomTotal: Double
    public let statusBreakdown: [String: Int]?
}

// MARK: - Budget Response

public struct BudgetResponse: Codable, Sendable {
    public let projectId: String
    public let projectName: String
    public let budgetTotalEntered: Double?
    public let rooms: [BudgetRoom]
    public let grandTotal: Double?
    public let grandMarkup: Double?
    public let vsBudgetPct: Double?
    public let categoryBreakdown: [String: Double]?
    public let statusBreakdown: [String: Int]?
}
