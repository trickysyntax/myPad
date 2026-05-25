import SwiftUI
import MyPadKit

/// Full asset detail — images, specs, finishes, and an "Add to Room" button
/// that bridges vendor browsing into the project/room selection pipeline.
struct AssetDetailView: View {
    let assetId: String
    let assetName: String
    let preselectedProjectId: String?
    let preselectedRoomId: String?
    let preselectedRoomName: String?

    init(assetId: String, assetName: String, preselectedProjectId: String? = nil, preselectedRoomId: String? = nil, preselectedRoomName: String? = nil) {
        self.assetId = assetId
        self.assetName = assetName
        self.preselectedProjectId = preselectedProjectId
        self.preselectedRoomId = preselectedRoomId
        self.preselectedRoomName = preselectedRoomName
    }

    @State private var asset: AssetTemplateDetail?
    @State private var finishes: [AssetFinishSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddToRoom = false
    @State private var addSuccessMessage: String?
    @State private var showEdit = false
    @State private var isUploadingPhoto = false
    @State private var selectedImageIndex = 0
    @State private var fullscreenPhotoURL: String?
    @State private var showAddFinish = false
    @State private var editingFinish: AssetFinishSummary?
    @State private var finishActionError: String?
    @State private var isReorderingFinish = false

    @Environment(\.dismiss) private var dismissNav

    private let api = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let asset {
                assetContent(asset)
            } else {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Failed to Load",
                    message: errorMessage
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.studioSurface)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let asset {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        PhotoSourceMenu(
                            onPhotoUploaded: { newURL in
                                Task { await appendImage(to: asset, url: newURL) }
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
                            Label("Edit Asset", systemImage: "pencil")
                        }

                        Button {
                            showAddToRoom = true
                        } label: {
                            Label("Add to Room", systemImage: "plus.rectangle.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let asset {
                EditAssetView(asset: asset) { updated in
                    self.asset = updated
                }
            }
        }
        .sheet(isPresented: $showAddFinish) {
            AssetFinishFormView(title: "Add Finish") { payload in
                try await createAssetFinish(payload)
            }
        }
        .sheet(item: $editingFinish) { finish in
            AssetFinishFormView(title: "Edit Finish", finish: finish) { payload in
                try await updateAssetFinish(finish, payload: payload)
            }
        }
        .sheet(isPresented: $showAddToRoom) {
            if let asset {
                AddToRoomSheet(
                    asset: asset,
                    finishes: finishes,
                    preselectedProjectId: preselectedProjectId,
                    preselectedRoomId: preselectedRoomId,
                    preselectedRoomName: preselectedRoomName,
                    onSuccess: { message in
                        addSuccessMessage = message
                        dismissNav()
                    }
                )
            }
        }
        .fullScreenCover(item: Binding(
            get: { fullscreenPhotoURL.map(PhotoViewerItem.init(urlString:)) },
            set: { newValue in fullscreenPhotoURL = newValue?.urlString }
        )) { item in
            FullscreenPhotoViewer(urlString: item.urlString)
        }
        .task { await load() }
    }

    // MARK: - Content

    private func assetContent(_ asset: AssetTemplateDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                imageBackground(asset)
                    .ignoresSafeArea(edges: .top)

                VStack(alignment: .leading, spacing: 0) {
                    productHeader(asset)

                    Divider().padding(.horizontal)
                    assetPhotoStrip(asset, imageUrls: asset.imageUrls ?? [])

                    if let desc = asset.description, !desc.isEmpty {
                        Divider().padding(.horizontal)
                        descriptionSection(desc)
                    }

                    Divider().padding(.horizontal)
                    specsSection(asset)

                    Divider().padding(.horizontal)
                    pricingSection(asset)

                    Divider().padding(.horizontal)
                    finishesSection
                }
                .background(Color.studioSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .offset(y: -20)
                .padding(.bottom, -20)
            }
        }
        .background(Color.studioSurface)
    }

    // MARK: - Image

    private func imageBackground(_ asset: AssetTemplateDetail) -> some View {
        GeometryReader { geo in
            ZStack {
                if let imageUrls = asset.imageUrls, !imageUrls.isEmpty {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlStr in
                            Group {
                                if let url = URL(string: urlStr) {
                                    AsyncImageLoader(url: url, size: CGSize(width: geo.size.width, height: 400))
                                        .frame(width: geo.size.width, height: 400)
                                        .clipped()
                                } else {
                                    assetImagePlaceholder
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
                        if selectedImageIndex >= count {
                            selectedImageIndex = max(0, count - 1)
                        }
                    }
                } else {
                    assetImagePlaceholder
                }
            }
        }
        .frame(height: 320)
    }

    private var assetImagePlaceholder: some View {
        Rectangle()
            .fill(Color.studioSurface)
            .frame(height: 320)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.studioAccent.opacity(0.3))
            }
    }

    private func assetPhotoStrip(_ asset: AssetTemplateDetail, imageUrls: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                sectionLabel("PHOTOS")
                Spacer()
                PhotoSourceMenu(
                    onPhotoUploaded: { newURL in
                        Task { await appendImage(to: asset, url: newURL) }
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
                        AssetPhotoThumbnail(
                            urlString: urlStr,
                            isSelected: index == selectedImageIndex,
                            onSelect: { selectedImageIndex = index },
                            onDelete: { Task { await deleteImage(from: asset, at: index) } }
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

    private func appendImage(to asset: AssetTemplateDetail, url: String) async {
        let existing = asset.imageUrls ?? []
        let updated = existing + [url]
        do {
            _ = try await api.updateAsset(id: asset.id, imageUrls: updated)
            selectedImageIndex = max(0, updated.count - 1)
            await load()
        } catch {}
    }

    private func deleteImage(from asset: AssetTemplateDetail, at index: Int) async {
        var existing = asset.imageUrls ?? []
        guard existing.indices.contains(index) else { return }
        existing.remove(at: index)
        do {
            _ = try await api.updateAsset(id: asset.id, imageUrls: existing.isEmpty ? nil : existing)
            selectedImageIndex = min(selectedImageIndex, max(0, existing.count - 1))
            await load()
        } catch {}
    }

    // MARK: - Product Header

    private func productHeader(_ asset: AssetTemplateDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(asset.name)
                        .font(.studioHeading(size: 24))
                        .foregroundStyle(Color.studioText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(asset.vendor?.name ?? "Style Source")
                        .font(.studioSubheading())
                        .foregroundStyle(Color.studioAccent)

                    if let sku = asset.sku {
                        Text("SKU: \(sku)")
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioSecondary)
                    }
                }

                Spacer()

                if asset.isDiscontinued {
                    Text("Discontinued")
                        .font(.studioCaption(size: 11))
                        .fontWeight(.semibold)
                        .tracking(0.2)
                        .foregroundStyle(Color.studioRejected)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.studioRejected.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                if let category = asset.category {
                    metadataPill(category, systemImage: "tag")
                }
                if let lead = asset.leadTimeWeeks {
                    metadataPill("\(lead) weeks", systemImage: "clock")
                }
                if finishes.count > 0 {
                    metadataPill("\(finishes.count) finishes", systemImage: "paintpalette")
                }
            }
        }
        .padding()
    }

    private func descriptionSection(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("DESCRIPTION")
            Text(desc)
                .font(.studioBody(size: 16))
                .foregroundStyle(Color.studioText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    // MARK: - Specifications

    private func specsSection(_ asset: AssetTemplateDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SPECIFICATIONS")

            VStack(spacing: 8) {
                if let dimensions = asset.dimensions {
                    specRow("Dimensions", dimensions, icon: "ruler")
                }
                if let lead = asset.leadTimeWeeks {
                    specRow("Lead Time", "\(lead) weeks", icon: "clock")
                }
                if let minOrder = asset.minimumOrder {
                    specRow("Minimum Order", minOrder, icon: "shippingbox")
                }
                if let care = asset.careInstructions {
                    specRow("Care", care, icon: "sparkles")
                }
                if let specUrl = asset.specSheetUrl, let url = URL(string: specUrl) {
                    Link(destination: url) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .frame(width: 18)
                                .foregroundStyle(Color.studioAccent)
                            Text("View Spec Sheet")
                                .font(.studioCaption(size: 14))
                                .foregroundStyle(Color.studioAccent)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func specRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(Color.studioSecondary)
            Text(label)
                .font(.studioCaption(size: 14))
                .foregroundStyle(Color.studioSecondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.studioCaption(size: 14))
                .foregroundStyle(Color.studioText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pricing

    private func pricingSection(_ asset: AssetTemplateDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("PRICING")

            HStack(spacing: 12) {
                priceCard(label: "MSRP", value: asset.msrp, color: Color.studioText)
                priceCard(label: "Trade Price", value: asset.tradePrice, color: Color.studioApproved)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func priceCard(label: String, value: Double?, color: Color) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.studioCaption(size: 11))
                    .fontWeight(.semibold)
                    .tracking(0.4)
                    .foregroundStyle(Color.studioSecondary)
                Text(formatPrice(value))
                    .font(.studioSubheading())
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.studioCard)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.studioDivider.opacity(0.65), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Finishes

    private var finishesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("FINISHES")
                Spacer()
                Button {
                    showAddFinish = true
                } label: {
                    Label("Add Finish", systemImage: "plus.circle")
                        .font(.studioCaption(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.studioAccent)
            }

            if let finishActionError {
                Text(finishActionError)
                    .font(.studioCaption(size: 13))
                    .foregroundStyle(Color.studioRejected)
            }

            if finishes.isEmpty {
                Text("No finishes listed for this product.")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(finishes.enumerated()), id: \.element.id) { index, finish in
                        FinishRow(
                            finish: finish,
                            canMoveUp: index > 0,
                            canMoveDown: index < finishes.count - 1,
                            onEdit: { editingFinish = finish },
                            onDelete: { Task { await deleteAssetFinish(finish) } },
                            onMoveUp: { Task { await moveFinish(from: index, to: index - 1) } },
                            onMoveDown: { Task { await moveFinish(from: index, to: index + 1) } }
                        )
                        if finish.id != finishes.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .opacity(isReorderingFinish ? 0.55 : 1)
            }
        }
        .padding()
    }

    private func metadataPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.studioCaption(size: 11))
            .fontWeight(.semibold)
            .foregroundStyle(Color.studioSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.studioSecondary.opacity(0.18))
            .clipShape(Capsule())
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.studioCaption(size: 11))
            .fontWeight(.semibold)
            .tracking(0.5)
            .foregroundStyle(Color.studioSecondary)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let assetDetail = api.getAsset(id: assetId)
            async let finishList = api.getFinishes(assetId: assetId)

            asset = try await assetDetail
            finishes = try await finishList
            errorMessage = nil
            finishActionError = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshFinishes() async {
        do {
            finishes = try await api.getFinishes(assetId: assetId)
            finishActionError = nil
        } catch {
            finishActionError = error.localizedDescription
        }
    }

    private func createAssetFinish(_ payload: AssetFinishFormPayload) async throws {
        _ = try await api.createFinish(
            assetId: assetId,
            name: payload.name,
            finishType: payload.finishType,
            source: payload.optionalString("source"),
            vendor: payload.optionalString("vendor"),
            patternColor: payload.optionalString("pattern_color"),
            grade: payload.optionalString("grade"),
            width: payload.optionalString("width"),
            repeatValue: payload.optionalString("repeat"),
            railroad: payload.railroad,
            yardage: payload.optionalString("yardage"),
            netPrice: payload.optionalString("net_price"),
            markup: payload.optionalString("markup"),
            salePrice: payload.optionalString("sale_price"),
            shipTo: payload.optionalString("ship_to"),
            photoUrl: payload.optionalString("photo_url"),
            swatchImageUrl: payload.optionalString("swatch_image_url"),
            imageUrls: payload.imageUrls,
            upchargePct: payload.upchargePct,
            inStock: payload.inStock,
            sortOrder: finishes.count
        )
        await refreshFinishes()
    }

    private func updateAssetFinish(_ finish: AssetFinishSummary, payload: AssetFinishFormPayload) async throws {
        _ = try await api.updateFinish(assetId: assetId, finishId: finish.id, fields: payload.fields)
        await refreshFinishes()
    }

    private func deleteAssetFinish(_ finish: AssetFinishSummary) async {
        do {
            try await api.deleteFinish(assetId: assetId, finishId: finish.id)
            await refreshFinishes()
        } catch {
            finishActionError = error.localizedDescription
        }
    }

    private func moveFinish(from source: Int, to destination: Int) async {
        guard finishes.indices.contains(source), finishes.indices.contains(destination), source != destination else { return }
        var reordered = finishes
        let item = reordered.remove(at: source)
        reordered.insert(item, at: destination)
        let prior = finishes
        finishes = reordered
        isReorderingFinish = true
        defer { isReorderingFinish = false }
        do {
            finishes = try await api.reorderFinishes(assetId: assetId, order: reordered.map(\.id))
            finishActionError = nil
        } catch {
            finishes = prior
            finishActionError = error.localizedDescription
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Finish Row

struct FinishRow: View {
    let finish: AssetFinishSummary
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            finishSwatch

            VStack(alignment: .leading, spacing: 4) {
                Text(finish.name)
                    .font(.studioCaption(size: 14))
                    .fontWeight(.medium)
                    .foregroundStyle(Color.studioText)

                finishMetaLine

                let details = detailChips
                if !details.isEmpty {
                    FlowPillRow(items: details)
                }
            }

            Spacer(minLength: 8)

            if !finish.inStock {
                Text("OOS")
                    .font(.studioCaption(size: 11))
                    .fontWeight(.medium)
                    .foregroundStyle(Color.studioOrdered)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.studioOrdered.opacity(0.14))
                    .clipShape(Capsule())
            }

            Menu {
                Button("Edit Finish", action: onEdit)
                Button("Move Up", action: onMoveUp)
                    .disabled(!canMoveUp)
                Button("Move Down", action: onMoveDown)
                    .disabled(!canMoveDown)
                Divider()
                Button("Delete Finish", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.studioCaption(size: 18))
                    .foregroundStyle(Color.studioSecondary)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var finishSwatch: some View {
        if let swatchUrl = finish.swatchImageUrl ?? finish.photoUrl ?? finish.imageUrls?.first,
           let url = URL(string: swatchUrl) {
            AsyncImageLoader(url: url, size: CGSize(width: 44, height: 44))
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.studioSecondary.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "paintpalette")
                        .font(.studioCaption())
                        .foregroundStyle(Color.studioSecondary)
                }
        }
    }

    private var finishMetaLine: some View {
        HStack(spacing: 6) {
            Text(finish.finishType.capitalized)
            if let vendor = finish.vendor, !vendor.isEmpty {
                Text("·")
                Text(vendor)
            } else if let source = finish.source, !source.isEmpty {
                Text("·")
                Text(source)
            }
            if let upcharge = finish.upchargePct, upcharge > 0 {
                Text("·")
                Text("+\(Int(upcharge))%")
                    .foregroundStyle(Color.studioApproved)
            }
        }
        .font(.studioCaption())
        .foregroundStyle(Color.studioSecondary)
    }

    private var detailChips: [String] {
        var items: [String] = []
        append("Pattern/Color", finish.patternColor, to: &items)
        append("Grade", finish.grade, to: &items)
        append("Width", finish.width, to: &items)
        append("Repeat", finish.repeat, to: &items)
        if finish.railroad == true { items.append("RR/Railroad") }
        append("Yardage", finish.yardage, to: &items)
        append("Net", finish.netPrice, to: &items)
        append("Markup", finish.markup, to: &items)
        append("Sale", finish.salePrice, to: &items)
        append("Ship To", finish.shipTo, to: &items)
        return items
    }

    private func append(_ label: String, _ value: String?, to items: inout [String]) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.append("\(label): \(value)")
    }
}

private struct FlowPillRow: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.studioCaption(size: 11))
                    .foregroundStyle(Color.studioSecondary)
                    .lineLimit(1)
            }
        }
    }
}

struct AssetFinishFormPayload {
    let fields: [String: Any]

    var name: String { fields["name"] as? String ?? "" }
    var finishType: String { fields["finish_type"] as? String ?? "finish" }
    var railroad: Bool? { fields["railroad"] as? Bool }
    var inStock: Bool? { fields["in_stock"] as? Bool }
    var imageUrls: [String]? { fields["image_urls"] as? [String] }
    var upchargePct: Double? { fields["upcharge_pct"] as? Double }

    func optionalString(_ key: String) -> String? {
        fields[key] as? String
    }
}

struct AssetFinishFormView: View {
    let title: String
    let finish: AssetFinishSummary?
    let onSave: (AssetFinishFormPayload) async throws -> Void

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
    @State private var imageUrlsText: String
    @State private var upchargePct: String
    @State private var inStock: Bool
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(title: String, finish: AssetFinishSummary? = nil, onSave: @escaping (AssetFinishFormPayload) async throws -> Void) {
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
        _imageUrlsText = State(initialValue: finish?.imageUrls?.joined(separator: "\n") ?? "")
        _upchargePct = State(initialValue: finish?.upchargePct.map { String($0) } ?? "")
        _inStock = State(initialValue: finish?.inStock ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Finish") {
                    TextField("Finish name", text: $name)
                    TextField("Type", text: $finishType)
                    Toggle("In Stock", isOn: $inStock)
                }

                Section("Source") {
                    TextField("Source", text: $source)
                    TextField("Vendor", text: $vendor)
                    TextField("Pattern/Color", text: $patternColor)
                    TextField("Grade", text: $grade)
                    TextField("Width", text: $width)
                    TextField("Repeat", text: $repeatText)
                    Toggle("RR/Railroad", isOn: $railroad)
                }

                Section("Pricing + Shipping") {
                    TextField("Yardage", text: $yardage)
                    TextField("Net", text: $netPrice)
                    TextField("Markup", text: $markup)
                    TextField("Sale", text: $salePrice)
                    TextField("Upcharge %", text: $upchargePct)
                        .keyboardType(.decimalPad)
                    TextField("Ship To", text: $shipTo)
                }

                Section("Photo") {
                    PhotoSourceMenu(
                        onPhotoUploaded: { newURL in
                            photoUrl = newURL
                            imageUrlsText = mergedImageURLs(including: newURL).joined(separator: "\n")
                        },
                        label: photoUrl.isEmpty ? "Upload Finish Photo" : "Replace Photo",
                        systemImage: "photo.badge.plus",
                        style: .bordered
                    )
                    TextField("Photo URL", text: $photoUrl)
                    TextField("Image URLs", text: $imageUrlsText, axis: .vertical)
                        .lineLimit(2...5)
                    Text("Paste one image URL per line. Uploaded photos are added here and used as the finish swatch.")
                        .font(.studioCaption(size: 12))
                        .foregroundStyle(Color.studioSecondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.studioRejected)
                    }
                }

                Section {
                    Button(isSaving ? "Saving…" : "Save Finish") { Task { await save() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(AssetFinishFormPayload(fields: buildFields()))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildFields() -> [String: Any] {
        var fields: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "finish_type": finishType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "finish" : finishType.trimmingCharacters(in: .whitespacesAndNewlines),
            "railroad": railroad,
            "in_stock": inStock,
        ]
        put("source", source, into: &fields)
        put("vendor", vendor, into: &fields)
        put("pattern_color", patternColor, into: &fields)
        put("grade", grade, into: &fields)
        put("width", width, into: &fields)
        put("repeat", repeatText, into: &fields)
        put("yardage", yardage, into: &fields)
        put("net_price", netPrice, into: &fields)
        put("markup", markup, into: &fields)
        put("sale_price", salePrice, into: &fields)
        put("ship_to", shipTo, into: &fields)
        put("photo_url", photoUrl, into: &fields)
        let urls = parsedImageURLs()
        if !urls.isEmpty {
            fields["image_urls"] = urls
            if fields["photo_url"] == nil { fields["photo_url"] = urls[0] }
            fields["swatch_image_url"] = fields["photo_url"]
        }
        if let pct = Double(upchargePct.trimmingCharacters(in: .whitespacesAndNewlines)) {
            fields["upcharge_pct"] = pct
        }
        return fields
    }

    private func put(_ key: String, _ value: String, into fields: inout [String: Any]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { fields[key] = trimmed }
    }

    private func parsedImageURLs() -> [String] {
        var urls = imageUrlsText
            .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let photo = photoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !photo.isEmpty && !urls.contains(photo) { urls.insert(photo, at: 0) }
        return urls
    }

    private func mergedImageURLs(including url: String) -> [String] {
        var urls = parsedImageURLs()
        if !urls.contains(url) { urls.insert(url, at: 0) }
        return urls
    }
}

// MARK: - Asset Photo Helpers

private struct AssetPhotoThumbnail: View {
    let urlString: String
    let isSelected: Bool
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

private struct PhotoViewerItem: Identifiable {
    let urlString: String
    var id: String { urlString }
}

private struct FullscreenPhotoViewer: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let url = URL(string: urlString) {
                ZoomableRemoteImage(url: url)
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

private struct ZoomableRemoteImage: UIViewRepresentable {
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

// MARK: - Add to Room Sheet

struct AddToRoomSheet: View {
    let asset: AssetTemplateDetail
    let finishes: [AssetFinishSummary]
    let preselectedProjectId: String?
    let preselectedRoomId: String?
    let preselectedRoomName: String?
    let onSuccess: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var projects: [ProjectSummary] = []
    @State private var rooms: [RoomDetail] = []
    @State private var selectedProject: ProjectSummary?
    @State private var selectedRoom: RoomDetail?
    @State private var selectedFinishIds: Set<String> = []
    @State private var copyAllFinishes = true
    @State private var quantity = 1
    @State private var isCreating = false
    @State private var isLoadingProjects = true
    @State private var isLoadingRooms = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                // Step 1: Destination (pre-selected or pickers)
                if let _ = preselectedProjectId, let _ = preselectedRoomId {
                    Section {
                        HStack {
                            Text("Adding to")
                                .foregroundStyle(Color.studioSecondary)
                            Spacer()
                            Text(preselectedRoomName ?? "Room")
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    Section("Project") {
                        if isLoadingProjects {
                            HStack {
                                ProgressView()
                                Text("Loading projects...")
                                    .foregroundStyle(Color.studioSecondary)
                            }
                        } else if projects.isEmpty {
                            Text("No projects available.")
                                .foregroundStyle(Color.studioSecondary)
                        } else {
                            Picker("Select Project", selection: $selectedProject) {
                                Text("Choose a project...").tag(nil as ProjectSummary?)
                                ForEach(projects) { project in
                                    Text(project.name)
                                        .tag(project as ProjectSummary?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Step 2: Pick room (depends on project)
                    if selectedProject != nil {
                        Section("Room") {
                            if isLoadingRooms {
                                HStack {
                                    ProgressView()
                                    Text("Loading rooms...")
                                        .foregroundStyle(Color.studioSecondary)
                                }
                            } else if rooms.isEmpty {
                                Text("No rooms in this project.")
                                    .foregroundStyle(Color.studioSecondary)
                            } else {
                                Picker("Select Room", selection: $selectedRoom) {
                                    Text("Choose a room...").tag(nil as RoomDetail?)
                                    ForEach(rooms) { room in
                                        Text(room.name).tag(room as RoomDetail?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }

                // Step 3: Pick finishes (if asset has finishes)
                if !finishes.isEmpty {
                    Section("Finishes") {
                        Toggle("Copy all asset finishes", isOn: $copyAllFinishes)
                            .onChange(of: copyAllFinishes) { _, newValue in
                                if newValue { selectedFinishIds = [] }
                            }

                        if copyAllFinishes {
                            Text("All \(finishes.count) finishes will be copied onto this selection so they can be edited independently later.")
                                .font(.studioCaption())
                                .foregroundStyle(Color.studioSecondary)
                        } else {
                            ForEach(finishes) { finish in
                                Button {
                                    if selectedFinishIds.contains(finish.id) {
                                        _ = selectedFinishIds.remove(finish.id)
                                    } else {
                                        _ = selectedFinishIds.insert(finish.id)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: selectedFinishIds.contains(finish.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedFinishIds.contains(finish.id) ? Color.studioAccent : Color.studioSecondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(finish.name)
                                                .foregroundStyle(Color.studioText)
                                            HStack(spacing: 6) {
                                                Text(finish.finishType.capitalized)
                                                if let upcharge = finish.upchargePct, upcharge > 0 {
                                                    Text("+\(Int(upcharge))%")
                                                }
                                                if !finish.inStock {
                                                    Text("OOS").foregroundStyle(Color.studioOrdered)
                                                }
                                            }
                                            .font(.studioCaption())
                                            .foregroundStyle(Color.studioSecondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Step 4: Quantity
                Section("Quantity") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                }

                // Error
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioRejected)
                    }
                }

                // Confirm
                Section {
                    Button {
                        Task { await addToRoom() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Add to Room")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canAdd || isCreating)
                }
            }
            .navigationTitle("Add to Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if preselectedProjectId == nil {
                    await loadProjects()
                }
            }
            .onChange(of: selectedProject) { _, newProject in
                if let project = newProject {
                    Task { await loadRooms(projectId: project.id) }
                } else {
                    rooms = []
                    selectedRoom = nil
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadProjects() async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        do {
            let response = try await api.listProjects(
                includeArchived: false,
                limit: 200
            )
            projects = response.data
        } catch {
            errorMessage = "Failed to load projects."
        }
    }

    private func loadRooms(projectId: String) async {
        isLoadingRooms = true
        selectedRoom = nil
        defer { isLoadingRooms = false }
        do {
            rooms = try await api.listRooms(projectId: projectId)
        } catch {
            rooms = []
            errorMessage = "Failed to load rooms."
        }
    }

    // MARK: - Create Selection

    private var canAdd: Bool {
        if preselectedProjectId != nil && preselectedRoomId != nil {
            return true
        }
        return selectedProject != nil && selectedRoom != nil
    }

    private func addToRoom() async {
        let projectId: String
        let roomId: String
        let roomName: String

        if let pid = preselectedProjectId, let rid = preselectedRoomId {
            projectId = pid
            roomId = rid
            roomName = preselectedRoomName ?? rid
        } else {
            guard let project = selectedProject,
                  let room = selectedRoom else { return }
            projectId = project.id
            roomId = room.id
            roomName = room.name
        }

        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            // Snapshot the trade price as unit_price (backend does this too, but we pass it explicitly)
            let price = asset.tradePrice

            let selection = try await api.createSelection(
                projectId: projectId,
                roomId: roomId,
                assetTemplateId: asset.id,
                finishIds: copyAllFinishes ? nil : Array(selectedFinishIds),
                copyFinishes: finishes.isEmpty ? nil : copyAllFinishes,
                quantity: quantity,
                unitPrice: price,
                notes: nil,
                groupKey: nil,
                rank: nil,
                sourceUrl: asset.imageUrls?.first
            )

            let selectedNames = finishes.filter { selectedFinishIds.contains($0.id) }.map(\.name)
            let finishLabel = copyAllFinishes
                ? (finishes.isEmpty ? "" : ", \(finishes.count) finishes")
                : (selectedNames.isEmpty ? "" : ", \(selectedNames.joined(separator: ", "))")
            onSuccess("Added \(selection.template?.name ?? asset.name)\(finishLabel) to \(roomName)")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Edit Asset Sheet

struct EditAssetView: View {
    let asset: AssetTemplateDetail
    let onSave: (AssetTemplateDetail) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var sku: String
    @State private var category: String
    @State private var description: String
    @State private var msrpText: String
    @State private var tradePriceText: String
    @State private var leadTimeWeeksText: String
    @State private var minimumOrder: String
    @State private var dimensions: String
    @State private var careInstructions: String
    @State private var isDiscontinued: Bool
    @State private var isLoading = false

    private let api = APIClient.shared
    private let categories = [
        "Furniture", "Lighting", "Textiles", "Flooring",
        "Wallcovering", "Hardware", "Plumbing", "Tile",
        "Accessories", "Art", "Other",
    ]

    init(asset: AssetTemplateDetail, onSave: @escaping (AssetTemplateDetail) -> Void) {
        self.asset = asset
        self.onSave = onSave
        _name = State(initialValue: asset.name)
        _sku = State(initialValue: asset.sku ?? "")
        _category = State(initialValue: asset.category ?? "Furniture")
        _description = State(initialValue: asset.description ?? "")
        _msrpText = State(initialValue: asset.msrp.map { String($0) } ?? "")
        _tradePriceText = State(initialValue: asset.tradePrice.map { String($0) } ?? "")
        _leadTimeWeeksText = State(initialValue: asset.leadTimeWeeks.map { String($0) } ?? "")
        _minimumOrder = State(initialValue: asset.minimumOrder ?? "")
        _dimensions = State(initialValue: asset.dimensions ?? "")
        _careInstructions = State(initialValue: asset.careInstructions ?? "")
        _isDiscontinued = State(initialValue: asset.isDiscontinued)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Product Name", text: $name)
                }
                Section("Basic Info") {
                    TextField("SKU", text: $sku)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in Text(cat).tag(cat) }
                    }
                }
                Section("Description") {
                    TextEditor(text: $description).frame(minHeight: 80)
                }
                Section("Pricing") {
                    HStack { Text("$").foregroundStyle(Color.studioSecondary); TextField("MSRP", text: $msrpText).keyboardType(.decimalPad) }
                    HStack { Text("$").foregroundStyle(Color.studioSecondary); TextField("Trade Price", text: $tradePriceText).keyboardType(.decimalPad) }
                }
                Section("Specifications") {
                    TextField("Lead Time (weeks)", text: $leadTimeWeeksText).keyboardType(.numberPad)
                    TextField("Minimum Order", text: $minimumOrder)
                    TextField("Dimensions", text: $dimensions)
                    TextField("Care Instructions", text: $careInstructions)
                }
                Section("Status") {
                    Toggle("Discontinued", isOn: $isDiscontinued)
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading { ProgressView() } else { Text("Save Changes").fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .navigationTitle("Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
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
            let updated = try await api.updateAsset(
                id: asset.id,
                name: name.trimmingCharacters(in: .whitespaces),
                sku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
                category: category,
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                msrp: Double(msrpText),
                tradePrice: Double(tradePriceText)
            )
            onSave(updated)
            dismiss()
        } catch {}
    }
}
