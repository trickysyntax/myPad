import SwiftUI
import MyPadKit

/// Browse all asset templates with advanced search and filtering.
/// Full tab-level view accessible from the Assets tab.
struct AllAssetsView: View {
    @State private var searchText = ""
    @State private var assets: [AssetTemplateSummary] = []
    @State private var isLoading = false

    // Filters
    @State private var selectedCategory: String? = nil
    @State private var selectedVendorId: String? = nil
    @State private var selectedVendorName: String? = nil
    @State private var minPrice: String = ""
    @State private var maxPrice: String = ""
    @State private var maxLeadTime: String = ""
    @State private var showDiscontinued = false
    @State private var showFilters = false
    @State private var showCreateAsset = false
    @State private var useCardView = false

    // Vendor search within filters
    @State private var vendorSearchText = ""
    @State private var vendorSuggestions: [VendorSummary] = []
    @State private var isSearchingVendor = false

    // Sort
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case priceHigh = "Price \u{2191}"
        case priceLow = "Price \u{2193}"
        case vendor = "Vendor"
    }

    private let api = APIClient.shared
    private let categories = [
        "Furniture", "Lighting", "Textiles", "Flooring",
        "Wallcovering", "Hardware", "Plumbing", "Tile",
        "Accessories", "Art", "Other",
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 500), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            searchBar
                .padding(.horizontal)
                .padding(.top, 8)

            if showFilters {
                filterPanel
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            sortPicker
                .padding(.horizontal)
                .padding(.vertical, 6)

            if isLoading {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if assets.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.studioSecondary)
                    Text(searchText.isEmpty && selectedCategory == nil
                        ? "Browse the asset library"
                        : "No assets match your filters")
                        .foregroundStyle(Color.studioSecondary)
                }
                Spacer()
            } else {
                if useCardView {
                    assetCardView
                } else {
                    assetListView
                }
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.studioSurface)
            .navigationTitle("Assets")
            .searchable(text: $searchText, prompt: "Search products...")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    Task { await search() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Menu {
                            Button { useCardView.toggle() } label: {
                                Label(useCardView ? "Show List View" : "Show Card View", systemImage: useCardView ? "list.bullet" : "square.grid.2x2")
                            }
                            Button { withAnimation { showFilters.toggle() } } label: {
                                Label(showFilters ? "Hide Filters" : "Show Filters", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            Button { showCreateAsset = true } label: {
                                Label("New Asset", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        AccountMenuButton()
                    }
                }
            }
            .task { await search() }
            .sheet(isPresented: $showCreateAsset) {
                CreateAssetView { _, _, _ in
                    Task { await search() }
                }
            }
        }
    }


    private var assetCardView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sortedAssets) { asset in
                    NavigationLink {
                        AssetDetailView(assetId: asset.id, assetName: asset.name)
                    } label: {
                        AssetCard(asset: asset)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var assetListView: some View {
        List {
            ForEach(sortedAssets) { asset in
                NavigationLink {
                    AssetDetailView(assetId: asset.id, assetName: asset.name)
                } label: {
                    AssetListRow(asset: asset)
                }
                .listRowBackground(Color.studioSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.studioSurface)
        .listStyle(.plain)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            if let vendorName = selectedVendorName {
                HStack(spacing: 4) {
                    Text(vendorName).font(.studioCaption(size: 14)).fontWeight(.medium)
                    Button {
                        selectedVendorId = nil
                        selectedVendorName = nil
                        Task { await search() }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.studioCaption()).foregroundStyle(Color.studioSecondary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.studioAccent.opacity(0.1))
                .clipShape(Capsule())
            }
            if selectedCategory != nil {
                HStack(spacing: 4) {
                    Text(selectedCategory!).font(.studioCaption(size: 14)).fontWeight(.medium)
                    Button {
                        selectedCategory = nil
                        Task { await search() }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.studioCaption()).foregroundStyle(Color.studioSecondary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.studioSecondary.opacity(0.18))
                .clipShape(Capsule())
            }
            Spacer()
            Text("\(assets.count) results").font(.studioCaption()).foregroundStyle(Color.studioSecondary)
        }
    }

    // MARK: - Filter Panel

    private var filterPanel: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CATEGORY").font(.studioCaption()).fontWeight(.semibold).foregroundStyle(Color.studioSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                                Task { await search() }
                            } label: {
                                Text(cat).font(.studioCaption(size: 14))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(selectedCategory == cat ? Color.studioAccent : Color.studioSecondary.opacity(0.18))
                                    .foregroundStyle(selectedCategory == cat ? Color.white : Color.studioText)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VENDOR").font(.studioCaption()).fontWeight(.semibold).foregroundStyle(Color.studioSecondary)
                HStack {
                    TextField("Search vendors...", text: $vendorSearchText)
                        .textFieldStyle(.plain)
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioText)
                        .padding(9)
                        .background(Color.studioSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.studioDivider.opacity(0.8), lineWidth: 0.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .onChange(of: vendorSearchText) { _, newValue in
                            if newValue.count >= 2 { Task { await searchVendors() } }
                            else { vendorSuggestions = [] }
                        }
                    if isSearchingVendor { ProgressView().scaleEffect(0.7) }
                }
                if !vendorSuggestions.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(vendorSuggestions) { vendor in
                                Button {
                                    selectedVendorId = vendor.id
                                    selectedVendorName = vendor.name
                                    vendorSearchText = ""
                                    vendorSuggestions = []
                                    Task { await search() }
                                } label: {
                                    HStack {
                                        Text(vendor.name).font(.studioCaption(size: 14))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8).padding(.horizontal, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("PRICE RANGE").font(.studioCaption()).fontWeight(.semibold).foregroundStyle(Color.studioSecondary)
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text("$").foregroundStyle(Color.studioSecondary).font(.studioCaption(size: 14))
                        TextField("Min", text: $minPrice).keyboardType(.decimalPad)
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioText)
                    }
                    .padding(8).background(Color.studioSecondary.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("\u{2013}").foregroundStyle(Color.studioSecondary)
                    HStack(spacing: 2) {
                        Text("$").foregroundStyle(Color.studioSecondary).font(.studioCaption(size: 14))
                        TextField("Max", text: $maxPrice).keyboardType(.decimalPad)
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioText)
                    }
                    .padding(8).background(Color.studioSecondary.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                    Button("Apply") { Task { await search() } }.font(.studioCaption(size: 14)).disabled(minPrice.isEmpty && maxPrice.isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("LEAD TIME (max weeks)").font(.studioCaption()).fontWeight(.semibold).foregroundStyle(Color.studioSecondary)
                HStack(spacing: 8) {
                    TextField("e.g. 12", text: $maxLeadTime).keyboardType(.numberPad)
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioText)
                        .padding(8).background(Color.studioSecondary.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 8)).frame(width: 100)
                    Toggle("Show discontinued", isOn: $showDiscontinued).font(.studioCaption(size: 14))
                        .onChange(of: showDiscontinued) { _, _ in Task { await search() } }
                }
            }
        }
        .padding()
        .background(Color.studioCard)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.studioDivider.opacity(0.65), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack {
            Text("Sort by").font(.studioCaption()).foregroundStyle(Color.studioSecondary)
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in Text(order.rawValue).tag(order) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var sortedAssets: [AssetTemplateSummary] {
        switch sortOrder {
        case .name: return assets.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .priceHigh: return assets.sorted { ($0.tradePrice ?? 0) > ($1.tradePrice ?? 0) }
        case .priceLow: return assets.sorted { ($0.tradePrice ?? 0) < ($1.tradePrice ?? 0) }
        case .vendor: return assets.sorted { ($0.vendor?.name ?? "zzz") < ($1.vendor?.name ?? "zzz") }
        }
    }

    // MARK: - Actions

    private func search() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.listAssets(q: searchText.isEmpty ? nil : searchText, vendorId: selectedVendorId, category: selectedCategory, limit: 200)
            var results = response.data
            if let min = Double(minPrice) { results = results.filter { ($0.tradePrice ?? $0.msrp ?? 0) >= min } }
            if let max = Double(maxPrice) { results = results.filter { ($0.tradePrice ?? $0.msrp ?? 0) <= max } }
            if let maxWeeks = Int(maxLeadTime) {
                results = results.filter { asset in
                    guard let weeks = asset.leadTimeWeeks else { return true }
                    return weeks <= maxWeeks
                }
            }
            if !showDiscontinued { results = results.filter { !$0.isDiscontinued } }
            assets = results
        } catch { assets = [] }
    }

    private func searchVendors() async {
        isSearchingVendor = true
        defer { isSearchingVendor = false }
        do {
            let response = try await api.listVendors(q: vendorSearchText, limit: 8)
            vendorSuggestions = response.data
        } catch { vendorSuggestions = [] }
    }
}

// MARK: - Asset List Row

struct AssetListRow: View {
    let asset: AssetTemplateSummary

    var body: some View {
        HStack(spacing: 12) {
            AssetMiniImage(urlString: asset.imageUrls?.first)
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(1)
                Text(asset.vendor?.name ?? "Style Source")
                    .font(.studioCaption(size: 13))
                    .foregroundStyle(Color.studioAccent)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let category = asset.category {
                        Text(category)
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.studioSecondary.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    if let price = asset.tradePrice ?? asset.msrp { PriceText(price, compact: true).font(.studioCaption(size: 11)) }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct AssetMiniImage: View {
    let urlString: String?

    var body: some View {
        ZStack {
            Color.studioAccent.opacity(0.06)
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    case .failure, .empty: placeholder
                    @unknown default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 62, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 20, weight: .light))
            .foregroundStyle(Color.studioAccent.opacity(0.35))
    }
}

// MARK: - Asset Card

struct AssetCard: View {
    let asset: AssetTemplateSummary

    private let imageHeight: CGFloat = 160

    private var imagePlaceholder: some View {
        Color.studioAccent.opacity(0.06)
            .overlay {
                Image(systemName: "photo")
                    .font(.title)
                    .fontWeight(.light)
                    .foregroundStyle(Color.studioAccent.opacity(0.3))
            }
    }

    private var photoArea: some View {
        GeometryReader { proxy in
            ZStack {
                if let urlStr = asset.imageUrls?.first, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            imagePlaceholder
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                } else {
                    imagePlaceholder
                }
            }
            .frame(width: proxy.size.width, height: imageHeight)
            .clipped()
        }
        .frame(height: imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .clipped()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            photoArea

            // Text below
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(2)

                Text(asset.vendor?.name ?? "Style Source")
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioAccent)
                    .lineLimit(1)

                HStack {
                    if let category = asset.category {
                        Text(category)
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let price = asset.tradePrice ?? asset.msrp {
                        Text("\u{00B7}")
                            .foregroundStyle(Color.studioSecondary)
                        PriceText(price, compact: true)
                            .font(.studioCaption())
                    }
                    Spacer()
                    if asset.isDiscontinued {
                        Text("DISC")
                            .font(.studioCaption())
                            .fontWeight(.medium)
                            .foregroundStyle(Color.studioProposed)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.studioProposed.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.studioCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.studioDivider.opacity(0.55), lineWidth: 0.5)
        }
        .shadow(color: Color.studioBrown.opacity(0.045), radius: 8, y: 3)
    }
}
