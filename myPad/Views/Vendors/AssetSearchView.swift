import SwiftUI
import MyPadKit
import UniformTypeIdentifiers

/// Global asset search across all vendors.
/// Offers search, create-new, and JSON import entry points.
/// When autoAddProjectId and autoAddRoomId are provided,
/// creating a new asset also immediately creates a selection in that room.
struct AssetSearchView: View {
    let autoAddProjectId: String?
    let autoAddRoomId: String?
    let autoAddRoomName: String?

    init(autoAddProjectId: String? = nil, autoAddRoomId: String? = nil, autoAddRoomName: String? = nil) {
        self.autoAddProjectId = autoAddProjectId
        self.autoAddRoomId = autoAddRoomId
        self.autoAddRoomName = autoAddRoomName
    }

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var assets: [AssetTemplateSummary] = []
    @State private var isLoading = false
    @State private var selectedCategory: String? = nil
    @State private var showCreateAsset = false
    @State private var showFileImporter = false
    @State private var importMessage: String?
    @State private var navigateToAssetId: String?
    @State private var navigateToAssetName: String?
    @State private var showCreatedAsset = false
    @State private var isAutoAdding = false
    
    // Quick-add from room context
    @State private var quickAddAsset: AssetTemplateSummary?
    @State private var showQuickAdd = false

    private let api = APIClient.shared

    /// Whether we're in room-context mode.
    private var isInRoomContext: Bool {
        autoAddProjectId != nil && autoAddRoomId != nil
    }

    var body: some View {
        ZStack {
            Group {
                if searchText.isEmpty && assets.isEmpty && importMessage == nil {
                    if isInRoomContext {
                        roomContextEmptyState
                    } else {
                        emptyStateWithActions
                    }
                } else if isLoading && assets.isEmpty {
                    ProgressView()
                } else if assets.isEmpty && importMessage == nil {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No Results",
                        message: "Try a different search term or category."
                    )
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search Assets")
            .searchable(text: $searchText, prompt: "Search products...")
            .onChange(of: searchText) { _, newValue in
                if newValue.count >= 2 || newValue.isEmpty {
                    Task { await search() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showCreateAsset = true
                        } label: {
                            Label(isInRoomContext ? "Create New Asset" : "Create New", systemImage: "plus.square")
                        }
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Import from JSON", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateAsset) {
                CreateAssetView(
                    autoAddProjectId: autoAddProjectId,
                    autoAddRoomId: autoAddRoomId
                ) { assetId, name, selectionsAlreadyCreated in
                    if selectionsAlreadyCreated {
                        // Placeholder mode — selections already created, just dismiss
                        dismiss()
                    } else if let pid = autoAddProjectId, let rid = autoAddRoomId {
                        // Normal mode with room context — auto-add selection
                        Task { await autoAddSelection(assetId: assetId, projectId: pid, roomId: rid) }
                    } else {
                        // Normal mode without room context — navigate to detail
                        navigateToAssetId = assetId
                        navigateToAssetName = name
                        showCreatedAsset = true
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .navigationDestination(isPresented: $showCreatedAsset) {
                if let id = navigateToAssetId {
                    AssetDetailView(assetId: id, assetName: navigateToAssetName ?? "New Asset")
                }
            }

            // Import status toast
            if let msg = importMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.studioCaption(size: 14))
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Auto-add loading overlay
            if isAutoAdding {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Adding to room...")
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Empty State (Room Context)

    private var roomContextEmptyState: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(Color.studioSecondary)
            VStack(spacing: 8) {
                Text("Add a Selection")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Search for an asset to add, create a new one, or set up a placeholder for client choice.")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            VStack(spacing: 12) {
                Button {
                    showCreateAsset = true
                } label: {
                    Label("Create New Asset", systemImage: "plus.square")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import from JSON", systemImage: "doc.badge.plus")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    // MARK: - Empty State with Actions

    private var emptyStateWithActions: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundStyle(Color.studioSecondary)

            VStack(spacing: 8) {
                Text("No Assets Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Search existing products, create a new one, or import from a JSON file.")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 12) {
                Button {
                    showCreateAsset = true
                } label: {
                    Label("Create New Asset", systemImage: "plus.square")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showFileImporter = true
                } label: {
                    Label("Import from JSON", systemImage: "doc.badge.plus")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            // Action buttons at top
            Section {
                HStack(spacing: 12) {
                    Button {
                        showCreateAsset = true
                    } label: {
                        Label("Create New", systemImage: "plus.square")
                            .font(.studioCaption(size: 14))
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import JSON", systemImage: "doc.badge.plus")
                            .font(.studioCaption(size: 14))
                    }
                    .buttonStyle(.bordered)
                }
                .listRowSeparator(.hidden)
            }

            // Category filter
            CategoryFilter(selected: $selectedCategory)
                .listRowSeparator(.hidden)

            ForEach(assets) { asset in
                NavigationLink {
                    AssetDetailView(
                        assetId: asset.id,
                        assetName: asset.name,
                        preselectedProjectId: autoAddProjectId,
                        preselectedRoomId: autoAddRoomId,
                        preselectedRoomName: autoAddRoomName
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            if let urlStr = asset.imageUrls?.first, let url = URL(string: urlStr) {
                                AsyncImageLoader(url: url, size: CGSize(width: 56, height: 56))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(asset.name)
                                    .font(.studioCaption(size: 14))
                                    .fontWeight(.medium)

                                if let vendor = asset.vendor {
                                    Text(vendor.name)
                                        .font(.studioCaption())
                                        .foregroundStyle(Color.studioAccent)
                                }

                                if let sku = asset.sku {
                                    Text("SKU: \(sku)")
                                        .font(.studioCaption(size: 11))
                                        .foregroundStyle(Color.studioSecondary)
                                }
                            }

                            Spacer()

                            if let price = asset.msrp {
                                PriceText(price, compact: true)
                            }
                        }

                        HStack {
                            if let category = asset.category {
                                Text(category)
                                    .font(.studioCaption(size: 11))
                                    .foregroundStyle(Color.studioSecondary)
                            }
                            if asset.finishCount > 0 {
                                Text("· \(asset.finishCount) finishes")
                                    .font(.studioCaption(size: 11))
                                    .foregroundStyle(Color.studioSecondary)
                            }
                            if asset.isDiscontinued {
                                Text("· Discontinued")
                                    .font(.studioCaption(size: 11))
                                    .foregroundStyle(Color.studioRejected)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.studioSurface)
            }
        }
        .scrollContentBackground(.hidden)
                .background(Color.studioSurface)
                .listStyle(.plain)
    }

    // MARK: - Search

    private func search() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.listAssets(
                q: searchText.isEmpty ? nil : searchText,
                category: selectedCategory,
                limit: 100
            )
            assets = response.data
        } catch {
            assets = []
        }
    }

    // MARK: - Auto-Add Selection

    /// Creates a selection immediately after asset creation when room context is known.
    private func autoAddSelection(assetId: String, projectId: String, roomId: String) async {
        isAutoAdding = true
        do {
            _ = try await api.createSelection(
                projectId: projectId,
                roomId: roomId,
                assetTemplateId: assetId,
                quantity: 1
            )
            // Success — dismiss the entire search sheet
            isAutoAdding = false
            dismiss()
        } catch {
            isAutoAdding = false
            importMessage = "Asset created but failed to add to room: \(error.localizedDescription)"
            dismissImportMessage()
        }
    }

    // MARK: - JSON Import

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await importAssets(from: url) }
        case .failure(let error):
            importMessage = "Failed to open file: \(error.localizedDescription)"
            dismissImportMessage()
        }
    }

    private func importAssets(from url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            importMessage = "Permission denied to read file."
            dismissImportMessage()
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data)

            let items: [[String: Any]]
            if let array = json as? [[String: Any]] {
                items = array
            } else if let dict = json as? [String: Any] {
                items = [dict]
            } else {
                importMessage = "Unexpected JSON structure. Expected an object or array of objects."
                dismissImportMessage()
                return
            }

            var created = 0
            var errors = 0

            for item in items {
                guard let assetName = item["name"] as? String, !assetName.isEmpty else {
                    errors += 1
                    continue
                }
                do {
                    _ = try await api.createAsset(
                        name: assetName,
                        vendorId: item["vendor_id"] as? String,
                        sku: item["sku"] as? String,
                        category: item["category"] as? String,
                        description: item["description"] as? String,
                        msrp: item["msrp"] as? Double,
                        tradePrice: item["trade_price"] as? Double,
                        leadTimeWeeks: item["lead_time_weeks"] as? Int,
                        minimumOrder: item["minimum_order"] as? String,
                        dimensions: item["dimensions"] as? String,
                        careInstructions: item["care_instructions"] as? String,
                        imageUrls: item["image_urls"] as? [String],
                        specSheetUrl: item["spec_sheet_url"] as? String,
                        isDiscontinued: item["is_discontinued"] as? Bool ?? false
                    )
                    created += 1
                } catch {
                    errors += 1
                }
            }

            importMessage = "Imported \(created) asset\(created == 1 ? "" : "s")\(errors > 0 ? " (\(errors) failed)" : "")"
            dismissImportMessage()

            // Refresh the list
            await search()

        } catch {
            importMessage = "Failed to parse JSON: \(error.localizedDescription)"
            dismissImportMessage()
        }
    }

    private func dismissImportMessage() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation { importMessage = nil }
        }
    }
}

// MARK: - Category Filter

struct CategoryFilter: View {
    @Binding var selected: String?

    private let categories = [
        nil as String?,
        "Furniture", "Lighting", "Textiles", "Flooring",
        "Wallcovering", "Hardware", "Plumbing", "Tile",
        "Accessories", "Art",
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selected = category
                    } label: {
                        Text(category ?? "All")
                            .font(.studioCaption(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected == category ? Color.studioAccent : Color.studioSecondary.opacity(0.22))
                            .foregroundStyle(selected == category ? Color.white : Color.studioText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}