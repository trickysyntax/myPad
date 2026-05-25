import SwiftUI
import MyPadKit

/// Create a new asset template, with four creation paths:
/// 1. Normal asset with existing vendor (autocomplete)
/// 2. Normal asset with NEW vendor (spawn CreateVendorView, pre-select on return)
/// 3. Placeholder asset — group name + candidate templates from catalog
/// 4. (Implicit) pick existing template — handled by AssetSearchView
///
/// Callback: onCreated(assetId, assetName, selectionsAlreadyCreated)
/// When selectionsAlreadyCreated is true (placeholder mode), the caller
/// should NOT auto-add a selection — they're already created.
struct CreateAssetView: View {
    @Environment(\.dismiss) private var dismiss

    /// If provided, placeholder mode creates selections directly in this room.
    let autoAddProjectId: String?
    let autoAddRoomId: String?

    /// Called on successful creation.
    let onCreated: (String, String, Bool) -> Void

    init(
        autoAddProjectId: String? = nil,
        autoAddRoomId: String? = nil,
        preselectedVendorId: String? = nil,
        preselectedVendorName: String? = nil,
        onCreated: @escaping (String, String, Bool) -> Void
    ) {
        self.autoAddProjectId = autoAddProjectId
        self.autoAddRoomId = autoAddRoomId
        self.onCreated = onCreated
        self._selectedVendorId = State(initialValue: preselectedVendorId)
        self._selectedVendorName = State(initialValue: preselectedVendorName)
    }

    // MARK: - Mode
    @State private var isPlaceholder = false

    // MARK: - Normal fields
    @State private var name = ""
    @State private var sku = ""
    @State private var category = "Furniture"
    @State private var description = ""
    @State private var msrpText = ""
    @State private var tradePriceText = ""
    @State private var leadTimeWeeksText = ""
    @State private var minimumOrder = ""
    @State private var dimensions = ""
    @State private var careInstructions = ""
    @State private var imageUrl = ""
    @State private var imageUrls: [String] = []
    @State private var specSheetUrl = ""
    @State private var isDiscontinued = false

    // Vendor
    @State private var selectedVendorId: String? = nil
    @State private var selectedVendorName: String? = nil
    @State private var vendorSearchText = ""
    @State private var vendorSuggestions: [VendorSummary] = []
    @State private var isSearchingVendor = false
    @State private var showVendorSuggestions = false
    @State private var showNewVendor = false

    // MARK: - Placeholder fields
    @State private var groupName = ""
    @State private var candidateAssets: [AssetTemplateSummary] = []
    @State private var showCandidatePicker = false

    // MARK: - Common
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let api = APIClient.shared
    private let categories = [
        "Furniture", "Lighting", "Textiles", "Flooring",
        "Wallcovering", "Hardware", "Plumbing", "Tile",
        "Accessories", "Art", "Other",
    ]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Mode pills (room context only)
                if autoAddProjectId != nil {
                    Section {
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { isPlaceholder = false }
                            } label: {
                                Text("Standard")
                                    .font(.studioCaption(size: 14))
                                    .fontWeight(isPlaceholder ? .regular : .semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isPlaceholder ? Color.clear : Color.studioAccent)
                                    .foregroundStyle(isPlaceholder ? Color.studioText : Color.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { isPlaceholder = true }
                            } label: {
                                Text("Placeholder")
                                    .font(.studioCaption(size: 14))
                                    .fontWeight(isPlaceholder ? .semibold : .regular)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isPlaceholder ? Color.studioAccent : Color.clear)
                                    .foregroundStyle(isPlaceholder ? Color.white : Color.studioText)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.studioSecondary.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text(isPlaceholder
                             ? "A placeholder represents a client choice. You'll add catalog options for the client to choose from."
                             : "Create a standard asset template with full product details.")
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioSecondary)
                    } header: {
                        Text("Type")
                    }
                }

                if isPlaceholder {
                    placeholderForm
                } else {
                    normalForm
                }

                // Error
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioRejected)
                    }
                }

                // Submit
                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text(isPlaceholder ? "Create Placeholder" : "Create Asset")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || isCreating)
                }
            }
            .navigationTitle("New Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    PhotoSourceMenu(
                        onPhotoUploaded: { url in
                            imageUrls.append(url)
                        },
                        systemImage: "photo.badge.plus",
                        style: .toolbar
                    )
                }
            }
            .sheet(isPresented: $showNewVendor) {
                CreateVendorView { id, vendorName in
                    selectedVendorId = id
                    selectedVendorName = vendorName
                }
            }
            .sheet(isPresented: $showCandidatePicker) {
                CandidatePickerView { asset in
                    if !candidateAssets.contains(where: { $0.id == asset.id }) {
                        candidateAssets.append(asset)
                    }
                }
            }
        }
    }

    // MARK: - Normal Form

    private var normalForm: some View {
        Group {
            Section("Name") {
                TextField("Product Name *", text: $name)
            }

            Section("Vendor") {
                vendorAutocomplete
                Button {
                    showNewVendor = true
                } label: {
                    Label("New Vendor", systemImage: "building.2.badge.plus")
                }
            }

            Section("Basic Info") {
                TextField("SKU", text: $sku)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in Text(cat).tag(cat) }
                }
            }

            Section("Description") {
                TextEditor(text: $description)
                    .frame(minHeight: 80)
            }

            Section("Pricing") {
                HStack {
                    Text("$").foregroundStyle(Color.studioSecondary)
                    TextField("MSRP", text: $msrpText).keyboardType(.decimalPad)
                }
                HStack {
                    Text("$").foregroundStyle(Color.studioSecondary)
                    TextField("Trade Price", text: $tradePriceText).keyboardType(.decimalPad)
                }
            }

            Section("Specifications") {
                TextField("Lead Time (weeks)", text: $leadTimeWeeksText).keyboardType(.numberPad)
                TextField("Minimum Order", text: $minimumOrder)
                TextField("Dimensions", text: $dimensions)
                TextField("Care Instructions", text: $careInstructions)
            }

            Section("Images") {
                if !imageUrls.isEmpty {
                    PhotoGalleryRow(photoUrls: imageUrls) { index in
                        imageUrls.remove(at: index)
                    }
                }
                TextField("Or paste an image URL", text: $imageUrl).keyboardType(.URL).autocapitalization(.none)
                TextField("Spec Sheet URL", text: $specSheetUrl).keyboardType(.URL).autocapitalization(.none)
            }

            Section("Status") {
                Toggle("Discontinued", isOn: $isDiscontinued)
            }
        }
    }

    // MARK: - Placeholder Form

    private var placeholderForm: some View {
        Group {
            Section("Group Name") {
                TextField("e.g. Side Chair, Coffee Table", text: $groupName)
                Text("This name groups the options together in the room.")
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)
            }

            Section {
                if candidateAssets.isEmpty {
                    Text("Add at least 2 catalog options for the client to choose from.")
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioSecondary)
                } else {
                    ForEach(Array(candidateAssets.enumerated()), id: \.element.id) { index, asset in
                        HStack(spacing: 10) {
                            Text("\(index + 1).")
                                .font(.studioCaption())
                                .foregroundStyle(Color.studioSecondary)
                                .frame(width: 20, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(asset.name)
                                    .font(.studioCaption(size: 14))
                                    .fontWeight(.medium)
                                if let vendor = asset.vendor {
                                    Text(vendor.name)
                                        .font(.studioCaption())
                                        .foregroundStyle(Color.studioAccent)
                                }
                            }

                            Spacer()

                            Button {
                                candidateAssets.removeAll { $0.id == asset.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.studioSecondary)
                            }
                        }
                    }
                }

                Button {
                    showCandidatePicker = true
                } label: {
                    Label("Add Option from Catalog", systemImage: "plus.circle")
                }
            } header: {
                Text("Options (\(candidateAssets.count))")
            } footer: {
                Text("Minimum 2 options required.")
            }
        }
    }

    // MARK: - Vendor Autocomplete

    private var vendorAutocomplete: some View {
        VStack(spacing: 0) {
            if let vendorName = selectedVendorName {
                HStack {
                    Text(vendorName).font(.studioCaption(size: 14))
                    Spacer()
                    Button {
                        selectedVendorId = nil
                        selectedVendorName = nil
                        vendorSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.studioSecondary)
                    }
                }
            } else {
                HStack {
                    TextField("Search vendors...", text: $vendorSearchText)
                        .onChange(of: vendorSearchText) { _, val in
                            if val.count >= 2 {
                                showVendorSuggestions = true
                                Task { await searchVendors() }
                            } else {
                                vendorSuggestions = []
                                showVendorSuggestions = false
                            }
                        }
                    if isSearchingVendor {
                        ProgressView().scaleEffect(0.7)
                    }
                }
            }

            if showVendorSuggestions && !vendorSuggestions.isEmpty {
                Divider().padding(.top, 8)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vendorSuggestions) { vendor in
                            Button {
                                selectedVendorId = vendor.id
                                selectedVendorName = vendor.name
                                vendorSearchText = ""
                                vendorSuggestions = []
                                showVendorSuggestions = false
                            } label: {
                                HStack {
                                    Text(vendor.name).font(.studioCaption(size: 14)).foregroundStyle(Color.studioText)
                                    Spacer()
                                    if let tag = vendor.tags?.first {
                                        Text(tag).font(.studioCaption()).foregroundStyle(Color.studioSecondary)
                                    }
                                }
                                .padding(.vertical, 10).padding(.horizontal, 4)
                            }
                            .buttonStyle(.plain)
                            if vendor.id != vendorSuggestions.last?.id { Divider() }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    // MARK: - Validation

    private var canSubmit: Bool {
        if isPlaceholder {
            return !groupName.isEmpty && candidateAssets.count >= 2
        } else {
            return !name.isEmpty
        }
    }

    // MARK: - Actions

    private func searchVendors() async {
        isSearchingVendor = true
        defer { isSearchingVendor = false }
        do {
            let response = try await api.listVendors(q: vendorSearchText, limit: 8)
            vendorSuggestions = response.data
        } catch {
            vendorSuggestions = []
        }
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        if isPlaceholder {
            await createPlaceholder()
        } else {
            await createNormal()
        }
    }

    private func createNormal() async {
        do {
            let urls: [String] = {
                var list = imageUrls
                if !imageUrl.isEmpty {
                    list.append(imageUrl.trimmingCharacters(in: .whitespaces))
                }
                return list
            }()
            let asset = try await api.createAsset(
                name: name.trimmingCharacters(in: .whitespaces),
                vendorId: selectedVendorId,
                sku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
                category: category,
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                msrp: Double(msrpText),
                tradePrice: Double(tradePriceText),
                leadTimeWeeks: Int(leadTimeWeeksText),
                minimumOrder: minimumOrder.isEmpty ? nil : minimumOrder.trimmingCharacters(in: .whitespaces),
                dimensions: dimensions.isEmpty ? nil : dimensions.trimmingCharacters(in: .whitespaces),
                careInstructions: careInstructions.isEmpty ? nil : careInstructions.trimmingCharacters(in: .whitespaces),
                imageUrls: urls.isEmpty ? nil : urls,
                specSheetUrl: specSheetUrl.isEmpty ? nil : specSheetUrl.trimmingCharacters(in: .whitespaces),
                isDiscontinued: isDiscontinued
            )
            onCreated(asset.id, asset.name, false)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createPlaceholder() async {
        do {
            // 1. Create a minimal asset template for the placeholder group
            let placeholderAsset = try await api.createAsset(
                name: groupName.trimmingCharacters(in: .whitespaces),
                category: "Placeholder",
                description: "Client choice — \(candidateAssets.count) options"
            )

            // 2. If room context is available, create selections for each candidate
            if let pid = autoAddProjectId, let rid = autoAddRoomId {
                for (index, candidate) in candidateAssets.enumerated() {
                    _ = try await api.createSelection(
                        projectId: pid,
                        roomId: rid,
                        assetTemplateId: candidate.id,
                        quantity: 1,
                        groupKey: groupName.trimmingCharacters(in: .whitespaces),
                        rank: index
                    )
                }
                // Also create a selection for the placeholder itself (as the group header)
                _ = try await api.createSelection(
                    projectId: pid,
                    roomId: rid,
                    assetTemplateId: placeholderAsset.id,
                    quantity: 1,
                    groupKey: groupName.trimmingCharacters(in: .whitespaces),
                    rank: nil
                )
                onCreated(placeholderAsset.id, placeholderAsset.name, true)
            } else {
                // No room context — caller will handle
                onCreated(placeholderAsset.id, placeholderAsset.name, false)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Candidate Picker Sheet

/// Simplified asset search for picking candidate templates in placeholder mode.
struct CandidatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var assets: [AssetTemplateSummary] = []
    @State private var isLoading = false

    let onSelect: (AssetTemplateSummary) -> Void
    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if assets.isEmpty && !searchText.isEmpty {
                    Text("No results").foregroundStyle(Color.studioSecondary)
                } else {
                    List(assets) { asset in
                        Button {
                            onSelect(asset)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.name).font(.studioCaption(size: 14)).fontWeight(.medium)
                                    if let vendor = asset.vendor {
                                        Text(vendor.name).font(.studioCaption()).foregroundStyle(Color.studioAccent)
                                    }
                                }
                                Spacer()
                                if let price = asset.tradePrice ?? asset.msrp {
                                    PriceText(price, compact: true).font(.studioCaption())
                                }
                            }
                        }
                        .foregroundStyle(Color.studioText)
                    }
                }
            }
            .navigationTitle("Pick Option")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search catalog...")
            .onChange(of: searchText) { _, val in
                if val.count >= 2 { Task { await search() } }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.listAssets(q: searchText, limit: 30)
            assets = response.data
        } catch {
            assets = []
        }
    }
}
