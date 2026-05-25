import SwiftUI

/// Refined status pill using studio palette.
struct StatusBadge: View {
    let status: String

    private var color: Color { .forStatus(status) }

    private var label: String {
        switch status {
        case "proposed":        return "Proposed"
        case "client_approved": return "Approved"
        case "rejected":        return "Rejected"
        case "ordered":         return "Ordered"
        case "delivered":       return "Delivered"
        case "installed":       return "Installed"
        default:                return status.capitalized
        }
    }

    var body: some View {
        Text(label)
            .font(.studioCaption(size: 11))
            .fontWeight(.semibold)
            .tracking(0.2)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .overlay {
                Capsule().stroke(color.opacity(0.18), lineWidth: 0.5)
            }
            .clipShape(Capsule())
    }
}
