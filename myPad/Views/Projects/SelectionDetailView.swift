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

    private let api = APIClient.shared

    init(selection: SelectionDetail, projectId: String, roomId: String) {
        self.selection = selection
        self.projectId = projectId
        self.roomId = roomId
        self._currentSelection = State(initialValue: selection)
        self._localAttachments = State(initialValue: selection.attachments ?? [])
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Fixed background image
            imageBackground
                .ignoresSafeArea(edges: .top)

            // Scrollable content panel
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Transparent spacer to push content below the image
                    Color.clear.frame(height: 260)

                    // Content card slides over the image
                    VStack(alignment: .leading, spacing: 0) {
                        // Attached photos
                        if !localAttachments.isEmpty {
                            photosSection
                            Divider().padding(.horizontal)
                        }

                        // Product info
                        productInfo

                        Divider().padding(.horizontal)
                        finishesSection

                        Divider().padding(.horizontal)

                        // Status pipeline
                        statusSection

                        Divider().padding(.horizontal)

                        // Pricing details
                        pricingSection

                        Divider().padding(.horizontal)

                        // Notes
                        notesSection

                        // Candidate group
                        if let groupKey = currentSelection.groupKey, !groupKey.isEmpty {
                            Divider().padding(.horizontal)
                            candidateGroupSection
                        }
                    }
                    .background(Color.studioSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .background(Color.studioSurface)
        .navigationTitle(currentSelection.template?.name ?? "Selection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    PhotoCaptureButton { url in
                        Task { await addPhoto(url) }
                    }
                    Button("Edit") { showEdit = true }
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
        .task {
            // Refresh from server on appear
            await refresh()
        }
    }

    // MARK: - Background Image

    private var imageBackground: some View {
        let imageUrl: URL? = {
            if let urlStr = currentSelection.sourceUrl, let url = URL(string: urlStr) {
                return url
            }
            if let urlStr = currentSelection.template?.imageUrls?.first, let url = URL(string: urlStr) {
                return url
            }
            return nil
        }()

        return GeometryReader { geo in
            if let url = imageUrl {
                AsyncImageLoader(url: url, size: CGSize(width: geo.size.width, height: 400))
                    .frame(width: geo.size.width, height: 400)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.studioSurface)
                    .frame(height: 280)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Color.studioAccent.opacity(0.3))
                    }
            }
        }
        .frame(height: 320)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTOS")
                .font(.studioCaption())
                .fontWeight(.semibold)
                .foregroundStyle(Color.studioSecondary)
                .padding(.horizontal)

            PhotoGalleryRow(photoUrls: localAttachments) { index in
                Task { await removePhoto(at: index) }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Product Info

    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let template = currentSelection.template {
                Text(template.name)
                    .font(.studioHeading(size: 22))
                    .foregroundStyle(Color.studioText)

                if let vendor = template.vendor {
                    Text(vendor.name)
                        .font(.studioSubheading())
                        .foregroundStyle(Color.studioAccent)
                }

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
                    Label("Add Finish", systemImage: "plus")
                        .font(.studioCaption(size: 12))
                }
                .buttonStyle(StudioButtonStyle(prominent: false))
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
        await persistAttachments(updated)
    }

    private func removePhoto(at index: Int) async {
        var updated = localAttachments
        updated.remove(at: index)
        localAttachments = updated
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

