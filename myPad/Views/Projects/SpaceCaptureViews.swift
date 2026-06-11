import SwiftUI
import MyPadKit
import QuickLook

#if canImport(RoomPlan)
import RoomPlan
#endif

struct SpaceCapturePreviewCard: View {
    let capture: SpaceCaptureSummary?
    let title: String
    let emptyTitle: String
    let emptyMessage: String
    let onOpen: () -> Void
    let onCapture: () -> Void

    var body: some View {
        Group {
            if let capture {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack {
                            LinearGradient(
                                colors: [Color.studioSecondary.opacity(0.18), Color.studioCard],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 42, weight: .light))
                                .foregroundStyle(Color.studioAccent)
                        }
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.studioSubheading(size: 20))
                                .foregroundStyle(Color.studioText)
                            Text(capturedDateText(capture) ?? "Tap to open the 3D space viewer")
                                .font(.studioCaption(size: 13))
                                .foregroundStyle(Color.studioSecondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.studioCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.studioDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.studioAccent.opacity(0.16))
                            Image(systemName: "viewfinder.circle")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(Color.studioAccent)
                        }
                        .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(emptyTitle)
                                .font(.studioSubheading(size: 20))
                                .foregroundStyle(Color.studioText)
                            Text(emptyMessage)
                                .font(.studioCaption(size: 13))
                                .foregroundStyle(Color.studioSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button(action: onCapture) {
                        Label("Capture 3D Space", systemImage: "cube.transparent")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudioButtonStyle(prominent: true))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.studioCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.studioDivider, lineWidth: 1)
                )
            }
        }
    }

    private func capturedDateText(_ capture: SpaceCaptureSummary) -> String? {
        if let capturedAt = capture.capturedAt ?? capture.createdAt {
            return "Captured \(capturedAt) · Tap to view"
        }
        return nil
    }
}

struct SpaceCaptureViewer: View {
    let capture: SpaceCaptureSummary

    @Environment(\.dismiss) private var dismiss
    @State private var localURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.studioSurface.ignoresSafeArea()

                if let localURL {
                    QuickLookPreview(url: localURL)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(16)
                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing 3D viewer…")
                            .font(.studioCaption(size: 14))
                            .foregroundStyle(Color.studioSecondary)
                    }
                } else {
                    EmptyStateView(
                        systemImage: "cube.transparent",
                        title: "Preview Unavailable",
                        message: errorMessage ?? "The 3D capture could not be opened on this device."
                    )
                    .padding()
                }
            }
            .navigationTitle("3D Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await preparePreview() }
        }
    }

    private func preparePreview() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let resolved = try resolveURL(capture.usdzUrl)
            if resolved.isFileURL {
                localURL = resolved
                return
            }

            let (downloadedURL, _) = try await URLSession.shared.download(from: resolved)
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("space-capture-\(capture.id).usdz")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: downloadedURL, to: destination)
            localURL = destination
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveURL(_ value: String) throws -> URL {
        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }
        guard let relative = URL(string: value, relativeTo: ServerConfig.baseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        return relative
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

enum SpaceCaptureScope: Equatable {
    case project(projectId: String, name: String)
    case room(projectId: String, roomId: String, name: String)

    var title: String {
        switch self {
        case .project: return "Capture 3D Project"
        case .room: return "Capture 3D Room"
        }
    }

    var subjectName: String {
        switch self {
        case .project(_, let name), .room(_, _, let name): return name
        }
    }
}

struct SpaceCaptureSheet: View {
    let scope: SpaceCaptureScope
    let onUploaded: (SpaceCaptureSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isUploading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.studioSurface.ignoresSafeArea()

                captureContent
            }
            .navigationTitle(scope.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isUploading)
                }
            }
            .overlay(alignment: .bottom) {
                if isUploading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Uploading 3D capture…")
                            .font(.studioCaption(size: 14))
                            .foregroundStyle(Color.studioText)
                    }
                    .padding(14)
                    .background(Color.studioCard)
                    .clipShape(Capsule())
                    .shadow(color: Color.studioText.opacity(0.12), radius: 14, y: 4)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    @ViewBuilder
    private var captureContent: some View {
#if canImport(RoomPlan)
        if RoomCaptureSession.isSupported {
            RoomPlanCaptureView { result in
                switch result {
                case .success(let payload):
                    Task { await upload(payload) }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 6) {
                    Text(scope.subjectName)
                        .font(.studioSubheading(size: 20))
                        .foregroundStyle(Color.studioText)
                    Text("Move slowly around the space to capture walls, openings, and major surfaces.")
                        .font(.studioCaption(size: 13))
                        .foregroundStyle(Color.studioSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(14)
                .background(Color.studioCard.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 12)
                .padding(.horizontal, 20)
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.studioCaption(size: 13))
                        .foregroundStyle(Color.studioRejected)
                        .padding(12)
                        .background(Color.studioCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 88)
                        .padding(.horizontal, 20)
                }
            }
        } else {
            unsupportedFallback
        }
#else
        unsupportedFallback
#endif
    }

    private var unsupportedFallback: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.studioAccent.opacity(0.16))
                Image(systemName: "ipad.and.iphone.slash")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.studioAccent)
            }
            .frame(width: 104, height: 104)

            VStack(spacing: 8) {
                Text("LiDAR Required")
                    .font(.studioHeading(size: 28))
                    .foregroundStyle(Color.studioText)
                Text("RoomPlan capture needs a physical iPad or iPhone with LiDAR. The Simulator can verify this fallback, menus, and viewer navigation, but cannot scan a room.")
                    .font(.studioBody(size: 17))
                    .foregroundStyle(Color.studioSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

#if canImport(RoomPlan)
    @available(iOS 16.0, *)
    private func upload(_ payload: RoomCapturePayload) async {
        guard !isUploading else { return }
        isUploading = true
        defer { isUploading = false }

        do {
            let metadata = [
                "capture_source": "RoomPlan",
                "client": "myPad Studio iPad",
                "scope_name": scope.subjectName,
            ]
            let capture: SpaceCaptureSummary
            switch scope {
            case .project(let projectId, _):
                capture = try await api.uploadProjectSpaceCapture(
                    projectId: projectId,
                    usdzData: payload.usdzData,
                    capturedRoomJSONData: payload.capturedRoomJSONData,
                    metadata: metadata
                )
            case .room(let projectId, let roomId, _):
                capture = try await api.uploadRoomSpaceCapture(
                    projectId: projectId,
                    roomId: roomId,
                    usdzData: payload.usdzData,
                    capturedRoomJSONData: payload.capturedRoomJSONData,
                    metadata: metadata
                )
            }
            onUploaded(capture)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
#endif
}

#if canImport(RoomPlan)
@available(iOS 16.0, *)
private struct RoomCapturePayload {
    let usdzData: Data
    let capturedRoomJSONData: Data?
}

@available(iOS 16.0, *)
private struct RoomPlanCaptureView: View {
    let onFinished: (Result<RoomCapturePayload, Error>) -> Void

    @State private var controller = RoomCaptureController()

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureRepresentable(controller: controller, onFinished: onFinished)
                .ignoresSafeArea()

            Button {
                controller.stop()
            } label: {
                Label("Finish Capture", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudioButtonStyle(prominent: true))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

@available(iOS 16.0, *)
private final class RoomCaptureController {
    weak var captureView: RoomCaptureView?

    func stop() {
        captureView?.captureSession.stop(pauseARSession: true)
    }
}

@available(iOS 16.0, *)
private struct RoomCaptureRepresentable: UIViewRepresentable {
    let controller: RoomCaptureController
    let onFinished: (Result<RoomCapturePayload, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.captureSession.delegate = context.coordinator
        view.delegate = context.coordinator
        controller.captureView = view
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
        return view
    }

    func updateUIView(_ view: RoomCaptureView, context: Context) {}

    static func dismantleUIView(_ view: RoomCaptureView, coordinator: Coordinator) {
        view.captureSession.stop(pauseARSession: true)
    }

    @objc(MyPadRoomCaptureCoordinator)
    final class Coordinator: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
        let onFinished: (Result<RoomCapturePayload, Error>) -> Void

        init(onFinished: @escaping (Result<RoomCapturePayload, Error>) -> Void) {
            self.onFinished = onFinished
            super.init()
        }

        required init?(coder: NSCoder) {
            self.onFinished = { _ in }
            super.init()
        }

        func encode(with coder: NSCoder) {}

        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            if let error {
                onFinished(.failure(error))
                return false
            }
            return true
        }

        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            if let error {
                onFinished(.failure(error))
                return
            }

            do {
                let usdzURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("roomplan-\(UUID().uuidString).usdz")
                try processedResult.export(to: usdzURL)
                let usdzData = try Data(contentsOf: usdzURL)
                let jsonData = try? JSONEncoder().encode(processedResult)
                try? FileManager.default.removeItem(at: usdzURL)
                onFinished(.success(RoomCapturePayload(usdzData: usdzData, capturedRoomJSONData: jsonData)))
            } catch {
                onFinished(.failure(error))
            }
        }
    }
}
#endif
