import SwiftUI
import MyPadKit

/// Full detail view for a single selection: product image, status stepper,
/// pricing, candidate group, notes, and edit capabilities.
struct SelectionDetailView: View {
    let selection: SelectionDetail
    let projectId: String
    let roomId: String

    @State private var currentSelection: SelectionDetail
    @State private var showEdit = false
    @State private var showAddFinish = false
    @State private var editingFinish: SelectionFinish?
    @State private var isUpdating = false
    @State private var localAttachments: [String] = []
    @State private var selectedHeroPhotoIndex = 0
    @State private var fullscreenPhotoURL: String?

    private let api = APIClient.shared

    init(selection: SelectionDetail, projectId: String, roomId: String) {
        self.selection = selection
        self.projectId = projectId
        self.roomId = roomId
        self._currentSelection = State(initialValue: selection)
        self._localAttachments = State(initialValue: selection.attachments ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                imageBackground
                    .ignoresSafeArea(edges: .top)

                VStack(alignment: .leading, spacing: 0) {
                    productInfo

                    Divider().padding(.horizontal)
                    photosSection

                    Divider().padding(.horizontal)
                    finishesSection

                    Divider().padding(.horizontal)
                    statusSection

                    Divider().padding(.horizontal)
                    pricingSection

                    Divider().padding(.horizontal)
                    notesSection

                    if let groupKey = currentSelection.groupKey, !groupKey.isEmpty {
                        Divider().padding(.horizontal)
                        candidateGroupSection
                    }
                }
                .background(Color.studioSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .offset(y: -20)
                .padding(.bottom, -20)
            }
        }
        .background(Color.studioSurface)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    PhotoSourceMenu(
                        onPhotoUploaded: { url in
                            Task { await addPhoto(url) }
                        },
                        label: "Add Photo",
                        systemImage: "photo.badge.plus",
                        style: .bordered
                    )

                    Divider()

                    Button {
                        showAddFinish = true
                    } label: {
                        Label("Add Finish", systemImage: "paintpalette")
                    }

                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit Selection", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditSelectionView(
                selection: currentSelection,
                projectId: projectId,
                roomId: roomId
            ) { updated in
                currentSelection = updated
            }
        }
        .sheet(isPresented: $showAddFinish) {
            SelectionFinishFormView(title: "Add Finish") { fields in
                _ = try await api.createSelectionFinish(
                    projectId: projectId,
                    roomId: roomId,
                    selectionId: currentSelection.id,
                    fields: fields
                )
                await refresh()
            }
        }
        .sheet(item: $editingFinish) { finish in
            SelectionFinishFormView(title: "Edit Finish", finish: finish) { fields in
                _ = try await api.updateSelectionFinish(
                    projectId: projectId,
                    roomId: roomId,
                    selectionId: currentSelection.id,
                    finishId: finish.id,
                    fields: fields
                )
                await refresh()
            }
        }
        .fullScreenCover(item: Binding(
            get: { fullscreenPhotoURL.map(SelectionPhotoViewerItem.init(urlString:)) },
            set: { newValue in fullscreenPhotoURL = newValue?.urlString }
        )) { item in
            SelectionFullscreenPhotoViewer(urlString: item.urlString)
        }
        .task {
            // Refresh from server on appear
            await refresh()
        }
    }

    // MARK: - Background Image

    private var heroPhotoURLs: [String] {
        var urls: [String] = []
        func append(_ candidate: String?) {
            guard let candidate, !candidate.isEmpty, URL(string: candidate) != nil else { return }
            if !urls.contains(candidate) { urls.append(candidate) }
        }

        append(currentSelection.sourceUrl)
        currentSelection.template?.imageUrls?.forEach { append($0) }
        localAttachments.forEach { append($0) }
        return urls
    }

    private var imageBackground: some View {
        let imageUrls = heroPhotoURLs

        return GeometryReader { geo in
            ZStack {
                if !imageUrls.isEmpty {
                    TabView(selection: $selectedHeroPhotoIndex) {
                        ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlStr in
                            Group {
                                if let url = URL(string: urlStr) {
                                    AsyncImageLoader(url: url, size: CGSize(width: geo.size.width, height: 400))
                                        .frame(width: geo.size.width, height: 400)
                                        .clipped()
                                } else {
                                    selectionImagePlaceholder
                                }
                            }
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture().onEnded { fullscreenPhotoURL = urlStr }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: imageUrls.count > 1 ? .automatic : .never))
                    .onChange(of: imageUrls.count) { _, count in
                        if selectedHeroPhotoIndex >= count {
                            selectedHeroPhotoIndex = max(0, count - 1)
                        }
                    }
                } else {
                    selectionImagePlaceholder
                }
            }
        }
        .frame(height: 320)
    }

    private var selectionImagePlaceholder: some View {
        Rectangle()
            .fill(Color.studioSurface)
            .frame(height: 320)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.studioAccent.opacity(0.3))
            }
    }

    // MARK: - Image (deprecated, replaced by imageBackground)

    private var imageSection: some View {
        let imageUrl: URL? = {
            if let urlStr = currentSelection.sourceUrl, let url = URL(string: urlStr) {
                return url
            }
            if let urlStr = currentSelection.template?.imageUrls?.first, let url = URL(string: urlStr) {
                return url
            }
            return nil
        }()

        return Group {
            if let url = imageUrl {
                AsyncImageLoader(url: url, size: CGSize(width: CGFloat.infinity, height: 280))
                    .frame(maxWidth: CGFloat.infinity)
                    .frame(height: 280)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.studioSurface)
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .fontWeight(.light)
                            .foregroundStyle(Color.studioAccent.opacity(0.3))
                    }
            }
        }
    }

    // MARK: - Photos

    private var photosSection: some View {
        let imageUrls = heroPhotoURLs

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                sectionLabel("PHOTOS")
                Spacer()
                PhotoSourceMenu(
                    onPhotoUploaded: { url in
                        Task { await addPhoto(url) }
                    },
                    label: imageUrls.isEmpty ? "Add Photo" : "Add",
                    systemImage: "photo.badge.plus",
                    style: .bordered
                )
            }

            if imageUrls.isEmpty {
                Text("No photos yet.")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlStr in
                            SelectionPhotoThumbnail(
                                urlString: urlStr,
                                isSelected: index == selectedHeroPhotoIndex,
                                canDelete: localAttachments.contains(urlStr),
                                onSelect: { selectedHeroPhotoIndex = index },
                                onDelete: {
                                    if let attachmentIndex = localAttachments.firstIndex(of: urlStr) {
                                        Task { await removePhoto(at: attachmentIndex) }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.horizontal, -16)
            }
        }
        .padding()
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.studioCaption())
            .fontWeight(.semibold)
            .tracking(0.4)
            .foregroundStyle(Color.studioSecondary)
    }

    // MARK: - Product Info

    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let template = currentSelection.template {
                Text(template.name)
                    .font(.studioHeading(size: 24))
                    .foregroundStyle(Color.studioText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(template.vendor?.name ?? "Style Source")
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioAccent)

                if let sku = template.sku {
                    Text("SKU: \(sku)")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }
            }

            if let finish = currentSelection.finish {
                HStack(spacing: 6) {
                    Text(finish.name)
                        .font(.studioCaption(size: 14))
                    Text("\u{00B7}")
                        .foregroundStyle(Color.studioSecondary)
                    Text(finish.finishType.capitalized)
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }
            }

            // Template specs
            if let template = currentSelection.template {
                if let category = template.category {
                    Label(category, systemImage: "tag")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }
                if let dimensions = template.dimensions {
                    Label(dimensions, systemImage: "ruler")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }
                if let leadTime = template.leadTimeWeeks {
                    Label("\(leadTime) weeks lead time", systemImage: "clock")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }
                if let specUrl = template.specSheetUrl, let url = URL(string: specUrl) {
                    Link(destination: url) {
                        Label("View Spec Sheet", systemImage: "doc.text")
                            .font(.studioCaption())
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Selection Finishes

    private var finishesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FINISHES")
                    .font(.studioCaption())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.studioSecondary)
                Spacer()
                Button { showAddFinish = true } label: {
                    Label("Add Finish", systemImage: "plus.circle")
                        .font(.studioCaption(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.studioAccent)
            }

            if (currentSelection.finishes ?? []).isEmpty {
                Text("No finishes copied onto this selection yet. Add a custom finish here; it will stay selection-specific and will not change the asset template.")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
            }

            ForEach(currentSelection.finishes ?? []) { finish in
                HStack(spacing: 12) {
                    if let swatch = finish.swatchImageUrl ?? finish.imageUrls?.first ?? finish.photoUrl,
                       let url = URL(string: swatch) {
                        AsyncImageLoader(url: url, size: CGSize(width: 42, height: 42))
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    } else {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.studioSecondary.opacity(0.18))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Image(systemName: "paintpalette")
                                    .font(.studioCaption())
                                    .foregroundStyle(Color.studioSecondary)
                            }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(finish.name)
                            .font(.studioCaption(size: 14))
                            .fontWeight(.medium)
                            .foregroundStyle(Color.studioText)
                        HStack(spacing: 6) {
                            Text(finish.finishType.capitalized)
                            if let grade = finish.grade { Text("Grade \(grade)") }
                            if let color = finish.patternColor { Text(color) }
                            if let sale = finish.salePrice { Text(sale).foregroundStyle(Color.studioAccent) }
                        }
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                    }

                    Spacer()

                    if finish.assetFinishId == nil {
                        Text("Custom")
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.studioSecondary.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Menu {
                        Button("Edit Finish") { editingFinish = finish }
                        Button("Delete Finish", role: .destructive) {
                            Task { await deleteFinish(finish) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.studioSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }

    // MARK: - Status Pipeline

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATUS")
                .font(.studioCaption())
                .fontWeight(.semibold)
                .foregroundStyle(Color.studioSecondary)

            // Visual stepper
            StatusStepper(
                currentStatus: currentSelection.status,
                onAdvance: { nextStatus in
                    Task { await advanceStatus(to: nextStatus) }
                },
                onRetreat: { prevStatus in
                    Task { await retreatStatus(to: prevStatus) }
                }
            )
        }
        .padding()
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRICING")
                .font(.studioCaption())
                .fontWeight(.semibold)
                .foregroundStyle(Color.studioSecondary)

            VStack(spacing: 6) {
                priceRow("Quantity", "\(currentSelection.quantity)")
                priceRow("Unit Price", formatPrice(currentSelection.unitPrice))

                if let markup = currentSelection.markupPct {
                    priceRow("Markup", "\(Int(markup))%")
                }

                Divider()

                if let price = currentSelection.unitPrice {
                    let total = price * Double(currentSelection.quantity)
                    let markupAmount = (currentSelection.markupPct ?? 0) / 100 * total
                    priceRow("Total", formatPrice(total + markupAmount))
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func priceRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.studioSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.studioText)
        }
        .font(.studioCaption(size: 14))
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.studioCaption())
                .fontWeight(.semibold)
                .foregroundStyle(Color.studioSecondary)

            if let notes = currentSelection.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Internal")
                        .font(.studioCaption(size: 11))
                        .foregroundStyle(Color.studioSecondary)
                    Text(notes)
                        .font(.studioCaption(size: 14))
                }
            }

            if let clientNotes = currentSelection.clientNotes, !clientNotes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Client")
                        .font(.studioCaption(size: 11))
                        .foregroundStyle(Color.studioSecondary)
                    Text(clientNotes)
                        .font(.studioCaption(size: 14))
                        .italic()
                }
            }

            if let instructions = currentSelection.instructions, !instructions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Instructions")
                        .font(.studioCaption(size: 11))
                        .foregroundStyle(Color.studioSecondary)
                    Text(instructions)
                        .font(.studioCaption(size: 14))
                }
            }

            if currentSelection.shipTo?.isEmpty == false {
                Label("Ship To: \(currentSelection.shipTo ?? "")", systemImage: "shippingbox")
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)
            }
        }
        .padding()
    }

    // MARK: - Candidate Group

    private var candidateGroupSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CANDIDATE GROUP")
                .font(.studioCaption())
                .fontWeight(.semibold)
                .foregroundStyle(Color.studioSecondary)

            HStack {
                Text(currentSelection.groupKey ?? "")
                    .font(.studioCaption(size: 14))
                Spacer()
                Text("Rank #\(currentSelection.rank ?? 0)")
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)

                if currentSelection.isSelected {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.studioApproved)
                }
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func addPhoto(_ url: String) async {
        let updated = localAttachments + [url]
        localAttachments = updated
        selectedHeroPhotoIndex = max(0, heroPhotoURLs.count - 1)
        await persistAttachments(updated)
    }

    private func removePhoto(at index: Int) async {
        var updated = localAttachments
        updated.remove(at: index)
        localAttachments = updated
        selectedHeroPhotoIndex = min(selectedHeroPhotoIndex, max(0, heroPhotoURLs.count - 1))
        await persistAttachments(updated)
    }

    private func persistAttachments(_ attachments: [String]) async {
        do {
            let updated = try await api.updateSelection(
                projectId: projectId,
                roomId: roomId,
                selectionId: currentSelection.id,
                attachments: attachments
            )
            currentSelection = updated
        } catch {}
    }

    private func advanceStatus(to newStatus: String) async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            let updated = try await api.updateSelectionStatus(
                projectId: projectId,
                roomId: roomId,
                selectionId: currentSelection.id,
                status: newStatus
            )
            currentSelection = updated
        } catch {}
    }

    private func retreatStatus(to prevStatus: String) async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            let updated = try await api.updateSelectionStatus(
                projectId: projectId,
                roomId: roomId,
                selectionId: currentSelection.id,
                status: prevStatus
            )
            currentSelection = updated
        } catch {}
    }

    private func deleteFinish(_ finish: SelectionFinish) async {
        do {
            try await api.deleteSelectionFinish(
                projectId: projectId,
                roomId: roomId,
                selectionId: currentSelection.id,
                finishId: finish.id
            )
            await refresh()
        } catch {}
    }

    private func refresh() async {
        do {
            // Re-fetch this specific selection
            let all = try await api.listSelections(projectId: projectId, roomId: roomId)
            if let updated = all.first(where: { $0.id == selection.id }) {
                currentSelection = updated
                localAttachments = updated.attachments ?? []
                selectedHeroPhotoIndex = min(selectedHeroPhotoIndex, max(0, heroPhotoURLs.count - 1))
            }
        } catch {}
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct SelectionPhotoThumbnail: View {
    let urlString: String
    let isSelected: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                AsyncImageLoader(url: URL(string: urlString), size: CGSize(width: 92, height: 92))
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.studioAccent : Color.studioDivider.opacity(0.7), lineWidth: isSelected ? 2 : 0.5)
                    }
            }
            .buttonStyle(.plain)

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SelectionPhotoViewerItem: Identifiable {
    let urlString: String
    var id: String { urlString }
}

private struct SelectionFullscreenPhotoViewer: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let url = URL(string: urlString) {
                SelectionZoomableRemoteImage(url: url)
                    .ignoresSafeArea()
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(24)
        }
    }
}

private struct SelectionZoomableRemoteImage: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.load(url: url, in: scrollView)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.layout(in: scrollView)
        context.coordinator.load(url: url, in: scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        private var currentURL: URL?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func load(url: URL, in scrollView: UIScrollView) {
            guard currentURL != url else { return }
            currentURL = url
            imageView?.image = nil
            Task {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = UIImage(data: data) else { return }
                await MainActor.run {
                    self.imageView?.image = image
                    scrollView.zoomScale = 1
                    self.layout(in: scrollView)
                }
            }
        }

        func layout(in scrollView: UIScrollView) {
            guard let imageView else { return }
            imageView.frame = scrollView.bounds
            scrollView.contentSize = scrollView.bounds.size
        }
    }
}

// MARK: - Selection Finish Form

struct SelectionFinishFormView: View {
    let title: String
    let finish: SelectionFinish?
    let onSave: ([String: Any]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var finishType: String
    @State private var source: String
    @State private var vendor: String
    @State private var patternColor: String
    @State private var grade: String
    @State private var width: String
    @State private var repeatText: String
    @State private var railroad: Bool
    @State private var yardage: String
    @State private var netPrice: String
    @State private var markup: String
    @State private var salePrice: String
    @State private var shipTo: String
    @State private var photoUrl: String
    @State private var isSelected: Bool
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(title: String, finish: SelectionFinish? = nil, onSave: @escaping ([String: Any]) async throws -> Void) {
        self.title = title
        self.finish = finish
        self.onSave = onSave
        _name = State(initialValue: finish?.name ?? "")
        _finishType = State(initialValue: finish?.finishType ?? "finish")
        _source = State(initialValue: finish?.source ?? "")
        _vendor = State(initialValue: finish?.vendor ?? "")
        _patternColor = State(initialValue: finish?.patternColor ?? "")
        _grade = State(initialValue: finish?.grade ?? "")
        _width = State(initialValue: finish?.width ?? "")
        _repeatText = State(initialValue: finish?.repeat ?? "")
        _railroad = State(initialValue: finish?.railroad ?? false)
        _yardage = State(initialValue: finish?.yardage ?? "")
        _netPrice = State(initialValue: finish?.netPrice ?? "")
        _markup = State(initialValue: finish?.markup ?? "")
        _salePrice = State(initialValue: finish?.salePrice ?? "")
        _shipTo = State(initialValue: finish?.shipTo ?? "")
        _photoUrl = State(initialValue: finish?.photoUrl ?? finish?.swatchImageUrl ?? finish?.imageUrls?.first ?? "")
        _isSelected = State(initialValue: finish?.isSelected ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Finish") {
                    TextField("Finish name", text: $name)
                    TextField("Type", text: $finishType)
                    Toggle("Selected for this selection", isOn: $isSelected)
                }
                Section("Source") {
                    TextField("Source", text: $source)
                    TextField("Vendor", text: $vendor)
                    TextField("Pattern/Color", text: $patternColor)
                    TextField("Grade", text: $grade)
                    TextField("Width", text: $width)
                    TextField("Repeat", text: $repeatText)
                    Toggle("Railroad", isOn: $railroad)
                }
                Section("Pricing + Shipping") {
                    TextField("Yardage", text: $yardage)
                    TextField("Net", text: $netPrice)
                    TextField("Markup", text: $markup)
                    TextField("Sale", text: $salePrice)
                    TextField("Ship To", text: $shipTo)
                }
                Section("Photo") {
                    TextField("Photo URL", text: $photoUrl)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Color.studioRejected) }
                }
                Section {
                    Button(isSaving ? "Saving…" : "Save Finish") { Task { await save() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var fields: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "finish_type": finishType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "finish" : finishType,
            "railroad": railroad,
            "is_selected": isSelected,
        ]
        func put(_ key: String, _ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { fields[key] = trimmed }
        }
        put("source", source); put("vendor", vendor); put("pattern_color", patternColor)
        put("grade", grade); put("width", width); put("repeat", repeatText)
        put("yardage", yardage); put("net_price", netPrice); put("markup", markup)
        put("sale_price", salePrice); put("ship_to", shipTo); put("photo_url", photoUrl)
        if !photoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["image_urls"] = [photoUrl.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        do {
            try await onSave(fields)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Status Stepper

struct StatusStepper: View {
    let currentStatus: String
    let onAdvance: (String) -> Void
    let onRetreat: (String) -> Void

    private let statuses = ["proposed", "client_approved", "ordered", "delivered", "installed"]
    private let labels = ["Proposed", "Approved", "Ordered", "Delivered", "Installed"]
    private let icons = ["circle.dotted", "checkmark.circle", "shippingbox", "truck.box", "wrench"]

    private var currentIndex: Int {
        statuses.firstIndex(of: currentStatus) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Visual stepper dots
            HStack(spacing: 0) {
                ForEach(Array(statuses.enumerated()), id: \.offset) { index, status in
                    VStack(spacing: 4) {
                        Image(systemName: index <= currentIndex ? "circle.fill" : "circle")
                            .font(.studioCaption())
                            .foregroundStyle(index <= currentIndex ? Color.studioAccent : Color.studioSecondary.opacity(0.3))
                            .frame(maxWidth: CGFloat.infinity)
                        Text(labels[index])
                            .font(.system(size: 10))
                            .foregroundStyle(index == currentIndex ? Color.studioText : Color.studioSecondary)
                    }

                    if index < statuses.count - 1 {
                        Rectangle()
                            .fill(index < currentIndex ? Color.studioAccent : Color.studioSecondary.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: 20)
                    }
                }
            }

            // Back / Forward buttons
            HStack {
                if currentIndex > 0 {
                    Button {
                        onRetreat(statuses[currentIndex - 1])
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text(labels[currentIndex - 1])
                        }
                        .font(.studioCaption(size: 14))
                    }
                    .buttonStyle(StudioButtonStyle(prominent: false))
                    Spacer()
                }

                Text(labels[currentIndex])
                    .font(.studioCaption())
                    .fontWeight(.medium)
                    .foregroundStyle(Color.forStatus(currentStatus))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.forStatus(currentStatus).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if currentIndex < statuses.count - 1 {
                    Spacer()
                    Button {
                        onAdvance(statuses[currentIndex + 1])
                    } label: {
                        HStack(spacing: 4) {
                            Text(labels[currentIndex + 1])
                            Image(systemName: "arrow.right")
                        }
                        .font(.studioCaption(size: 14))
                    }
                    .buttonStyle(StudioButtonStyle(prominent: false))
                }
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - Edit Selection Sheet

struct EditSelectionView: View {
    let selection: SelectionDetail
    let projectId: String
    let roomId: String
    let onUpdated: (SelectionDetail) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var quantity: Int
    @State private var unitPrice: String
    @State private var markupPct: String
    @State private var notes: String
    @State private var clientNotes: String
    @State private var shipTo: String
    @State private var isLoading = false

    init(selection: SelectionDetail, projectId: String, roomId: String, onUpdated: @escaping (SelectionDetail) -> Void) {
        self.selection = selection
        self.projectId = projectId
        self.roomId = roomId
        self.onUpdated = onUpdated

        _quantity = State(initialValue: selection.quantity)
        _unitPrice = State(initialValue: selection.unitPrice.map { String($0) } ?? "")
        _markupPct = State(initialValue: selection.markupPct.map { String($0) } ?? "")
        _notes = State(initialValue: selection.notes ?? "")
        _clientNotes = State(initialValue: selection.clientNotes ?? "")
        _shipTo = State(initialValue: selection.shipTo ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                    TextField("Unit Price", text: $unitPrice)
                        .keyboardType(.decimalPad)
                    TextField("Markup %", text: $markupPct)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Internal Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Client Notes", text: $clientNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Shipping") {
                    TextField("Ship To", text: $shipTo)
                }

                Section {
                    Button("Save Changes") {
                        Task { await save() }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit Selection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await APIClient.shared.updateSelection(
                projectId: projectId,
                roomId: roomId,
                selectionId: selection.id,
                quantity: quantity,
                unitPrice: Double(unitPrice),
                markupPct: Double(markupPct),
                notes: notes.isEmpty ? nil : notes,
                clientNotes: clientNotes.isEmpty ? nil : clientNotes,
                shipTo: shipTo.isEmpty ? nil : shipTo
            )
            onUpdated(updated)
            dismiss()
        } catch {}
    }
}

