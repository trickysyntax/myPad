import SwiftUI
import MyPadKit

/// Project budget breakdown — room subtotals, grand total, vs-budget bar, status breakdown.
struct BudgetView: View {
    let projectId: String

    @State private var budget: BudgetResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading budget...")
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let budget {
                budgetContent(budget)
            } else if let error = errorMessage {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Failed to Load Budget",
                    message: error
                )
            }
        }
        .background(Color.studioSurface)
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Content

    @ViewBuilder
    private func budgetContent(_ budget: BudgetResponse) -> some View {
        VStack(spacing: 0) {
            // Category breakdown
            categoryBreakdownSection(budget)
                .padding()

            Divider().padding(.horizontal)

                // Room breakdowns
                VStack(alignment: .leading, spacing: 0) {
                    Text("ROOMS")
                        .font(.studioCaption())
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.studioSecondary)
                        .padding(.horizontal)
                        .padding(.top)

                    ForEach(budget.rooms, id: \.roomId) { room in
                        roomRow(room)
                        if room.roomId != budget.rooms.last?.roomId {
                            Divider().padding(.leading, 56)
                        }
                    }
                }

                Divider().padding(.horizontal)

                // Grand total
                grandTotal(budget)
                    .padding()

                // Status breakdown
                statusBreakdown(budget)
                    .padding()
            }
    }

    // MARK: - Category Breakdown Bar

    private let categoryOrder = [
        "Furniture", "Lighting", "Textiles", "Flooring",
        "Wallcovering", "Hardware", "Plumbing", "Tile",
        "Accessories", "Art", "Other",
    ]

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Furniture":    return Color(red: 0.44, green: 0.28, blue: 0.14)  // studioBrown
        case "Lighting":     return Color(red: 0.78, green: 0.62, blue: 0.24)  // studioAccent
        case "Textiles":     return Color(red: 0.75, green: 0.45, blue: 0.45)  // muted rose
        case "Flooring":     return Color(red: 0.65, green: 0.40, blue: 0.28)  // terracotta
        case "Wallcovering": return Color(red: 0.42, green: 0.55, blue: 0.35)  // sage
        case "Hardware":     return Color(red: 0.45, green: 0.45, blue: 0.50)  // warm steel
        case "Plumbing":     return Color(red: 0.35, green: 0.50, blue: 0.60)  // muted blue
        case "Tile":         return Color(red: 0.25, green: 0.45, blue: 0.42)  // deep teal
        case "Accessories":  return Color(red: 0.55, green: 0.40, blue: 0.55)  // muted plum
        case "Art":          return Color(red: 0.60, green: 0.30, blue: 0.30)  // deep rose
        default:             return Color.studioSecondary
        }
    }

    private func categoryBreakdownSection(_ budget: BudgetResponse) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(budget.projectName)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Spent \(formatCompact(budget.grandTotal))")
                        .font(.studioCaption(size: 14))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.studioText)
                    if let target = budget.budgetTotalEntered {
                        Text("of \(formatCompact(target)) budget")
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioSecondary)
                    }
                }
            }

            // Segmented bar
            if let breakdown = budget.categoryBreakdown, !breakdown.isEmpty {
                categoryBar(breakdown: breakdown, grandTotal: budget.grandTotal ?? 0,
                            budgetTarget: budget.budgetTotalEntered)
            }
        }
        .padding()
        .background(Color.studioCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func categoryBar(breakdown: [String: Double], grandTotal: Double, budgetTarget: Double?) -> some View {
        let totalForBar = budgetTarget ?? grandTotal
        let sorted = sortedCategories(breakdown)

        if totalForBar > 0, !sorted.isEmpty {
            VStack(spacing: 10) {
            // The bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.studioSecondary.opacity(0.12))
                        .frame(height: 22)

                    HStack(spacing: 0) {
                        ForEach(sorted, id: \.0) { cat, amount in
                            let width = (amount / totalForBar) * geo.size.width
                            if width > 2 {
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(categoryColor(cat))
                                    .frame(width: max(width, 2))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(height: 22)

            // Legend
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 6) {
                ForEach(sorted, id: \.0) { cat, amount in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryColor(cat))
                            .frame(width: 8, height: 8)
                        Text(cat)
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(formatCompact(amount))
                            .font(.studioCaption(size: 11))
                            .fontWeight(.medium)
                            .foregroundStyle(Color.studioText)
                    }
                }
            }
        }
        }
    }

    private func sortedCategories(_ breakdown: [String: Double]) -> [(String, Double)] {
        var sorted: [(String, Double)] = []
        for cat in categoryOrder {
            if let amount = breakdown[cat], amount > 0 {
                sorted.append((cat, amount))
            }
        }
        let known = Set(sorted.map(\.0))
        for (cat, amount) in breakdown.sorted(by: { $0.value > $1.value }) {
            if !known.contains(cat), amount > 0 {
                sorted.append((cat, amount))
            }
        }
        return sorted
    }

    // MARK: - Room Row

    private func roomRow(_ room: BudgetRoom) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "square.split.bottomrightquarter")
                .foregroundStyle(Color.studioSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.roomName)
                    .font(.studioCaption(size: 14))
                    .fontWeight(.medium)
                Text(countLabel(room.selectionCount, singular: "selection"))
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)

                if room.markupTotal > 0 {
                    Text("Subtotal: \(formatCompact(room.subtotal)) + Markup: \(formatCompact(room.markupTotal))")
                        .font(.studioCaption(size: 11))
                        .foregroundStyle(Color.studioSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCompact(room.roomTotal))
                    .font(.studioCaption(size: 14))
                    .fontWeight(.semibold)

                // Mini status breakdown
                if let statuses = room.statusBreakdown, !statuses.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(statuses.keys.sorted()), id: \.self) { status in
                            Circle()
                                .fill(colorForStatus(status))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Grand Total

    private func grandTotal(_ budget: BudgetResponse) -> some View {
        HStack {
            Text("GRAND TOTAL")
                .font(.studioCaption(size: 14))
                .fontWeight(.bold)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCompact(budget.grandTotal))
                    .font(.title3)
                    .fontWeight(.bold)
                if let markup = budget.grandMarkup {
                    Text("Markup: \(formatCompact(markup))")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }
            }
        }
    }

    // MARK: - Status Breakdown

    @ViewBuilder
    private func statusBreakdown(_ budget: BudgetResponse) -> some View {
        if let breakdown = budget.statusBreakdown, !breakdown.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("STATUS BREAKDOWN")
                    .font(.studioCaption())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.studioSecondary)

                let total = Double(breakdown.values.reduce(0, +))
                ForEach(Array(breakdown.keys.sorted()), id: \.self) { status in
                    let count = breakdown[status] ?? 0
                    let pct = total > 0 ? Double(count) / total : 0

                    HStack(spacing: 8) {
                        StatusBadge(status: status)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForStatus(status).opacity(0.3))
                                .frame(width: geo.size.width * pct, height: 8)
                        }
                        .frame(height: 8)

                        Text("\(count)")
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioSecondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            budget = try await api.getBudget(projectId: projectId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func formatCompact(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "proposed":        return .blue
        case "client_approved": return .green
        case "rejected":        return .red
        case "ordered":         return .orange
        case "delivered":       return .purple
        case "installed":       return .teal
        default:                return .gray
        }
    }
}
