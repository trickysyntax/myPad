import SwiftUI

/// Loads a remote image with a placeholder.
/// Caching is handled by nginx Cache-Control headers on /uploads/ paths.
struct AsyncImageLoader: View {
    let url: URL?
    let size: CGSize

    init(url: URL?, size: CGSize = CGSize(width: 60, height: 60)) {
        self.url = url
        self.size = size
    }

    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    placeholder
                case .empty:
                    ProgressView()
                        .frame(width: size.width, height: size.height)
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.15))
            .frame(width: size.width, height: size.height)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(Color.studioSecondary)
            }
    }
}
