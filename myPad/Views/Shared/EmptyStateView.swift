import SwiftUI

/// Refined empty state with serif heading and studio colors.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String?
    let actionLabel: String?
    let action: (() -> Void)?

    init(
        systemImage: String = "tray",
        title: String,
        message: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.studioAccent.opacity(0.5))

            Text(title)
                .font(.studioHeading(size: 20))
                .foregroundStyle(Color.studioText)

            if let message {
                Text(message)
                    .font(.studioBody())
                    .foregroundStyle(Color.studioSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .lineSpacing(4)
            }

            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                }
                .buttonStyle(StudioButtonStyle(prominent: true))
                .padding(.top, 4)
            }

            Spacer()
        }
    }
}
