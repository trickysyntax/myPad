import Foundation

/// Formats prices for display in the UI.
enum PriceFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    /// Format a Double as a USD price string (e.g. "$4,200.00").
    static func format(_ price: Double?) -> String {
        guard let price = price else { return "—" }
        return formatter.string(from: NSNumber(value: price)) ?? "$\(String(format: "%.2f", price))"
    }

    /// Format a price without cents for compact display (e.g. "$4,200").
    static func compact(_ price: Double?) -> String {
        guard let price = price else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }

    /// Format a percentage (e.g. "20%").
    static func percent(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        return String(format: "%.0f%%", value)
    }
}
