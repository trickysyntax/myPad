import SwiftUI

/// Formats a price value with studio typography.
struct PriceText: View {
    let price: Double?
    let compact: Bool

    init(_ price: Double?, compact: Bool = false) {
        self.price = price
        self.compact = compact
    }

    var body: some View {
        if let price {
            Text(price, format: .currency(code: "USD"))
                .font(compact ? .studioCaption() : .studioSubheading())
                .fontWeight(.medium)
                .foregroundStyle(Color.studioText)
        } else {
            Text("\u{2014}")
                .foregroundStyle(Color.studioSecondary)
        }
    }
}
