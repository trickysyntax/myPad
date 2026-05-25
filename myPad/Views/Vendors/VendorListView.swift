import SwiftUI
import MyPadKit

/// Browse and search 960+ vendors.
struct VendorListView: View {
    @State private var vendors: [VendorSummary] = []
    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    @State private var isLoading = false
    @State private var currentPage = 0
    @State private var hasMore = true
    @State private var showCreateVendor = false
    @State private var searchReloadTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var useCardView = false

    private let api = APIClient.shared
    private let pageSize = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && vendors.isEmpty {
                    Spacer()
                    ProgressView("Loading vendors...")
                    Spacer()
                } else {
                    contentView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.studioSurface)
            .navigationTitle("Vendors")
            .searchable(text: $searchText, prompt: "Search vendors...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Menu {
                            Button { useCardView.toggle() } label: {
                                Label(useCardView ? "Show List View" : "Show Card View", systemImage: useCardView ? "list.bullet" : "square.grid.2x2")
                            }
                            Button { showCreateVendor = true } label: {
                                Label("New Vendor", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        AccountMenuButton()
                    }
                }
            }
        }
        .task { await load(reset: true) }
        .sheet(isPresented: $showCreateVendor) {
            CreateVendorView { _, _ in
                Task { await load(reset: true) }
            }
        }
        .onChange(of: searchText) { _, _ in
            searchReloadTask?.cancel()
            searchReloadTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await load(reset: true)
            }
        }
        .onChange(of: selectedTag) { _, _ in
            searchReloadTask?.cancel()
            Task { await load(reset: true) }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if useCardView {
            vendorCardView
        } else {
            vendorList
        }
    }

    private let vendorColumns = [GridItem(.adaptive(minimum: 220, maximum: 340), spacing: 16)]

    private var vendorCardView: some View {
        ScrollView {
            TagPills(selected: $selectedTag)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            LazyVGrid(columns: vendorColumns, spacing: 16) {
                ForEach(vendors) { vendor in
                    NavigationLink {
                        VendorDetailView(vendorId: vendor.id, vendorName: vendor.name)
                    } label: {
                        VendorCard(vendor: vendor)
                    }
                    .buttonStyle(.plain)
                }
                if hasMore {
                    Button(isLoading ? "Loading…" : "Load more vendors") { Task { await loadMore() } }
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioAccent)
                        .disabled(isLoading)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.studioCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .refreshable { await load(reset: true) }
    }

    // MARK: - List

    private var vendorList: some View {
        List {
            // Category tag pills
            TagPills(selected: $selectedTag)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.studioSurface)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            ForEach(vendors) { vendor in
                NavigationLink {
                    VendorDetailView(vendorId: vendor.id, vendorName: vendor.name)
                } label: {
                    VendorRow(vendor: vendor)
                }
                .listRowBackground(Color.studioSurface)
            }

            // Manual pagination. The previous auto-loading ProgressView could keep
            // firing while visible and pull the entire migrated vendor table into
            // the simulator, which made this tab feel locked up.
            if hasMore {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Load more vendors") {
                            Task { await loadMore() }
                        }
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioAccent)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.studioSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.studioSurface)
        .listStyle(.plain)
        .refreshable { await load(reset: true) }
    }

    // MARK: - Data

    private func load(reset: Bool = false) async {
        if isLoading && !reset { return }
        if reset {
            currentPage = 0
            hasMore = true
            errorMessage = nil
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let offset = reset ? 0 : currentPage * pageSize
            let response = try await api.listVendors(
                q: searchText.isEmpty ? nil : searchText,
                tag: selectedTag,
                limit: pageSize,
                offset: offset
            )
            if reset {
                vendors = response.data
            } else {
                vendors.append(contentsOf: response.data)
            }
            currentPage = (offset / pageSize) + 1
            hasMore = vendors.count < response.total
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        await load(reset: false)
    }
}

// MARK: - Tag Pills

struct TagPills: View {
    @Binding var selected: String?

    private let tags = [
        nil as String?,
        "Furniture", "Lighting", "Textiles", "Flooring",
        "Wallcovering", "Hardware", "Plumbing", "Tile",
        "Accessories", "Art", "Antiques",
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        selected = tag
                    } label: {
                        Text(tag ?? "All")
                            .font(.studioCaption(size: 14))
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selected == tag
                                    ? Color.studioAccent
                                    : Color.studioSecondary.opacity(0.22)
                            )
                            .foregroundStyle(
                                selected == tag ? .white : .primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Vendor Row

struct VendorRow: View {
    let vendor: VendorSummary

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VendorLogoView(urlString: vendor.logoUrl, size: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text(vendor.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(1)

                if let website = vendor.website, !website.isEmpty {
                    Text(website)
                        .font(.studioCaption(size: 11))
                        .foregroundStyle(Color.studioAccent)
                        .lineLimit(1)
                }

                tagPills
            }

            Spacer(minLength: 12)

            if let tier = vendor.pricingTier, !tier.isEmpty {
                Text(tier)
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.studioSecondary.opacity(0.18))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    private var tagPills: some View {
        HStack(spacing: 6) {
            if let category = vendor.category, !category.isEmpty {
                VendorTagPill(text: category, emphasized: true)
            }
            ForEach(Array((vendor.tags ?? []).prefix(3)), id: \.self) { tag in
                VendorTagPill(text: tag, emphasized: false)
            }
        }
    }
}

struct VendorCard: View {
    let vendor: VendorSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VendorLogoView(urlString: vendor.logoUrl, size: nil)
                .frame(height: 140)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                Text(vendor.name)
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                    .lineLimit(2)
                if let website = vendor.website, !website.isEmpty {
                    Text(website)
                        .font(.studioCaption(size: 11))
                        .foregroundStyle(Color.studioAccent)
                        .lineLimit(1)
                }
                HStack {
                    tagPills
                    Spacer()
                    if let tier = vendor.pricingTier {
                        Text(tier)
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.studioCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.studioDivider.opacity(0.55), lineWidth: 0.5) }
        .shadow(color: Color.studioBrown.opacity(0.045), radius: 8, y: 3)
    }

    private var tagPills: some View {
        HStack(spacing: 5) {
            if let category = vendor.category, !category.isEmpty { VendorTagPill(text: category, emphasized: true) }
            ForEach(Array((vendor.tags ?? []).prefix(2)), id: \.self) { tag in VendorTagPill(text: tag, emphasized: false) }
        }
    }
}

struct VendorLogoView: View {
    let urlString: String?
    let size: CGFloat?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.studioAccent.opacity(0.06))
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit().padding(8)
                    case .failure, .empty: placeholder
                    @unknown default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        Image(systemName: "building.2")
            .font(.system(size: size == nil ? 36 : 20, weight: .light))
            .foregroundStyle(Color.studioAccent.opacity(0.35))
    }
}

struct VendorTagPill: View {
    let text: String
    let emphasized: Bool

    var body: some View {
        Text(text)
            .font(.studioCaption(size: 10))
            .fontWeight(emphasized ? .semibold : .regular)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(emphasized ? Color.studioAccent.opacity(0.12) : Color.studioSecondary.opacity(0.18))
            .foregroundStyle(emphasized ? Color.studioAccent : Color.studioSecondary)
            .clipShape(Capsule())
    }
}
