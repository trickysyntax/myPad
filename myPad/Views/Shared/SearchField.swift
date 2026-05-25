import SwiftUI

/// Reusable search field with clear button.
struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    init(_ placeholder: String = "Search", text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.studioSecondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.studioText)
                .font(.studioCaption(size: 14))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.studioSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.studioCard)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.studioDivider.opacity(0.8), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
