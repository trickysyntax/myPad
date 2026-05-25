import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import MyPadKit

// MARK: - Photo Source Menu

/// Reusable photo source picker — Take Photo, Choose from Library, or Choose File.
/// Uploads the selected image to the server and returns the URL.
struct PhotoSourceMenu: View {
    let onPhotoUploaded: (String) -> Void
    let label: String
    let systemImage: String
    let style: Style

    enum Style {
        case bordered      // standard bordered button
        case hero           // large camera icon on image placeholder
        case toolbar        // compact toolbar icon
    }

    init(onPhotoUploaded: @escaping (String) -> Void, label: String = "Add Photo", systemImage: String = "camera", style: Style = .bordered) {
        self.onPhotoUploaded = onPhotoUploaded
        self.label = label
        self.systemImage = systemImage
        self.style = style
    }

    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploading = false

    var body: some View {
        Button {
            showActionSheet = true
        } label: {
            switch style {
            case .hero:
                VStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.title)
                        .fontWeight(.light)
                    Text(label)
                        .font(.studioCaption())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.studioSurface)
                .foregroundStyle(Color.studioAccent.opacity(0.6))
            case .toolbar:
                Image(systemName: systemImage)
            case .bordered:
                Label(label, systemImage: systemImage)
                    .font(.studioCaption(size: 14))
            }
        }
        .disabled(isUploading)
        .overlay {
            if isUploading {
                ProgressView()
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showActionSheet) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotosPicker = true }
            Button("Choose File...") { showFilePicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                Task { await uploadImage(image) }
            }
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .jpeg, .png, .heic],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        Task { await uploadImage(image) }
                    }
                }
            case .failure:
                break
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadImage(image)
                }
                selectedPhotoItem = nil
            }
        }
    }

    private func uploadImage(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = "photo_\(Int(Date().timeIntervalSince1970)).jpg"

        do {
            let response = try await APIClient.shared.uploadImage(data: data, filename: filename)
            if let url = response.url ?? response.path {
                let fullURL: String
                if url.hasPrefix("http") {
                    fullURL = url
                } else if url.hasPrefix("/") {
                    fullURL = ServerConfig.baseURL.absoluteString + url
                } else {
                    fullURL = ServerConfig.baseURL.absoluteString + "/" + url
                }
                onPhotoUploaded(fullURL)
            }
        } catch {
            // Silently fail — parent can handle
        }
    }
}

// MARK: - Camera Capture (UIImagePickerController wrapper)

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onDismiss: { dismiss() })
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onDismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onDismiss = onDismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
        }
    }
}

// MARK: - Photo Thumbnail Gallery

// MARK: - Legacy compatibility

/// Convenience wrapper matching the old API.
struct PhotoCaptureButton: View {
    let onPhotoUploaded: (String) -> Void

    var body: some View {
        PhotoSourceMenu(onPhotoUploaded: onPhotoUploaded, style: .bordered)
    }
}
struct PhotoGalleryRow: View {
    let photoUrls: [String]
    let onDelete: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(photoUrls.enumerated()), id: \.offset) { index, urlStr in
                    ZStack(alignment: .topTrailing) {
                        AsyncImageLoader(
                            url: URL(string: urlStr),
                            size: CGSize(width: 100, height: 100)
                        )
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            onDelete(index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                                .padding(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
