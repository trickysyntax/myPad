import SwiftUI
import MyPadKit

/// Vendor detail — vendor info, key contacts, prose, and their asset templates.
struct VendorDetailView: View {
    let vendorId: String
    let vendorName: String

    @State private var vendor: VendorDetail?
    @State private var assets: [AssetTemplateSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showEditVendor = false
    @State private var showNewAsset = false
    @State private var createdAssetId: String?
    @State private var createdAssetName: String?
    @State private var showCreatedAsset = false

    private let api = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let vendor {
                vendorContent(vendor)
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
            if let vendor {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditVendor = true
                        } label: {
                            Label("Edit Vendor", systemImage: "pencil")
                        }

                        Button {
                            showNewAsset = true
                        } label: {
                            Label("New Asset from Vendor", systemImage: "plus.rectangle.on.rectangle")
                        }

                        Divider()

                        PhotoSourceMenu(
                            onPhotoUploaded: { url in
                                Task { await updateLogo(url) }
                            },
                            label: vendor.logoUrl == nil ? "Add Logo Photo" : "Update Logo Photo",
                            systemImage: "photo.badge.plus",
                            style: .bordered
                        )

                        if vendor.logoUrl != nil {
                            Button(role: .destructive) {
                                Task { await removeLogo() }
                            } label: {
                                Label("Remove Logo", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditVendor) {
            if let vendor {
                EditVendorView(vendor: vendor) { updated in
                    self.vendor = updated
                }
            }
        }
        .sheet(isPresented: $showNewAsset) {
            if let vendor {
                CreateAssetView(
                    preselectedVendorId: vendor.id,
                    preselectedVendorName: vendor.name
                ) { assetId, assetName, _ in
                    createdAssetId = assetId
                    createdAssetName = assetName
                    showCreatedAsset = true
                    Task { await load() }
                }
            }
        }
        .navigationDestination(isPresented: $showCreatedAsset) {
            if let createdAssetId {
                AssetDetailView(assetId: createdAssetId, assetName: createdAssetName ?? "Asset")
            }
        }
        .task { await load() }
    }

    // MARK: - Content

    private func vendorContent(_ vendor: VendorDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                vendorHero(vendor)

                VStack(alignment: .leading, spacing: 0) {
                    vendorHeader(vendor)

                    if hasContactInfo(vendor) {
                        Divider().padding(.horizontal)
                        contactSection(vendor)
                    }

                    if let prose = vendor.prose, !prose.isEmpty {
                        Divider().padding(.horizontal)
                        aboutSection(prose)
                    }

                    Divider().padding(.horizontal)
                    assetsSection
                }
                .background(Color.studioSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .background(Color.studioSurface)
    }

    private func vendorHero(_ vendor: VendorDetail) -> some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text(vendor.name)
                    .font(.studioHeading(size: 32))
                    .foregroundStyle(Color.studioText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let category = vendor.category {
                        Text(category)
                            .font(.studioCaption(size: 14))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.studioAccent)
                            .lineLimit(2)
                    }

                    if let tier = vendor.pricingTier {
                        Text(tier)
                            .font(.studioCaption(size: 12))
                            .fontWeight(.semibold)
                            .tracking(0.2)
                            .foregroundStyle(Color.studioAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.studioAccent.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            logoPreview(vendor)
                .frame(width: 210, height: 138)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(
            LinearGradient(
                colors: [
                    Color.studioAccent.opacity(0.10),
                    Color.studioSecondary.opacity(0.10),
                    Color.studioSurface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func logoPreview(_ vendor: VendorDetail) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.studioCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.studioDivider, lineWidth: 1)
                )

            Group {
                if let logoUrl = vendor.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(18)
                        case .failure, .empty:
                            vendorHeroPlaceholder
                        @unknown default:
                            vendorHeroPlaceholder
                        }
                    }
                } else {
                    vendorHeroPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        }
    }

    private var vendorHeroPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.studioAccent.opacity(0.12),
                        Color.studioSecondary.opacity(0.10),
                        Color.studioSurface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .center) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(Color.studioAccent.opacity(0.26))
            }
    }

    private func vendorHeader(_ vendor: VendorDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let knownFor = vendor.knownFor, !knownFor.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("KNOWN FOR")
                    Text(knownFor)
                        .font(.studioBody(size: 17))
                        .foregroundStyle(Color.studioText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            let facts = vendorFacts(vendor)
            if !facts.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(facts, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 4) {
                            sectionLabel(label.uppercased())
                            Text(value)
                                .font(.studioCaption(size: 14))
                                .foregroundStyle(Color.studioText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.studioCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.studioDivider, lineWidth: 1)
                        )
                    }
                }
            }

            if let tags = vendor.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.studioCaption(size: 11))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.studioSecondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.studioSecondary.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func vendorFacts(_ vendor: VendorDetail) -> [(String, String)] {
        [
            ("Pricing", vendor.pricingDetail),
            ("Target Market", vendor.targetMarket),
            ("Credit Terms", vendor.creditTerms),
            ("Leadership", vendor.leadership),
        ].compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
    }

    private func aboutSection(_ prose: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("ABOUT")
            Text(prose)
                .font(.studioBody(size: 16))
                .foregroundStyle(Color.studioText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    private func hasContactInfo(_ vendor: VendorDetail) -> Bool {
        vendor.website != nil || vendor.email != nil ||
        vendor.phone != nil || vendor.address != nil
    }

    private func contactSection(_ vendor: VendorDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("CONTACT")

            VStack(alignment: .leading, spacing: 10) {
                if let website = vendor.website,
                   let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") {
                    Link(destination: url) {
                        Label(website, systemImage: "safari")
                            .font(.studioCaption(size: 14))
                            .foregroundStyle(Color.studioAccent)
                    }
                }

                if let email = vendor.email {
                    Label(email, systemImage: "envelope")
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioSecondary)
                }

                if let phone = vendor.phone {
                    Label(phone, systemImage: "phone")
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioSecondary)
                }

                if let address = vendor.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioSecondary)
                }
            }
        }
        .padding()
    }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Products")
                    .font(.studioSubheading())
                    .foregroundStyle(Color.studioText)
                Spacer()
                Text("\(assets.count) assets")
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioSecondary)
            }

            if assets.isEmpty {
                Text("No products listed")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(assets) { asset in
                        NavigationLink {
                            AssetDetailView(assetId: asset.id, assetName: asset.name)
                        } label: {
                            AssetRow(asset: asset)
                        }
                        .buttonStyle(.plain)

                        if asset.id != assets.last?.id {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
            }
        }
        .padding()
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
            async let vendorDetail = api.getVendor(id: vendorId)
            async let assetList = api.listAssets(vendorId: vendorId, limit: 200)

            vendor = try await vendorDetail
            assets = try await assetList.data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLogo(_ url: String) async {
        do {
            let updated = try await api.updateVendor(id: vendorId, logoUrl: url)
            vendor = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeLogo() async {
        do {
            let updated = try await api.updateVendor(id: vendorId, clearLogo: true)
            vendor = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Asset Row

struct AssetRow: View {
    let asset: AssetTemplateSummary

    var body: some View {
        HStack(spacing: 12) {
            assetThumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name)
                    .font(.studioSubheading(size: 16))
                    .foregroundStyle(Color.studioText)
                    .lineLimit(2)

                Text(asset.vendor?.name ?? "Style Source")
                    .font(.studioCaption())
                    .foregroundStyle(Color.studioAccent)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let sku = asset.sku {
                        Text(sku)
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                    }

                    if let price = asset.msrp {
                        PriceText(price, compact: true)
                            .font(.studioCaption())
                    }

                    if asset.finishCount > 0 {
                        Text("\(asset.finishCount) finishes")
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                    }

                    if let lead = asset.leadTimeWeeks {
                        Text("\(lead) wks")
                            .font(.studioCaption(size: 11))
                            .foregroundStyle(Color.studioSecondary)
                    }
                }
            }

            Spacer()

            if asset.isDiscontinued {
                Text("DISC")
                    .font(.studioCaption(size: 11))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.studioRejected)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.studioRejected.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var assetThumbnail: some View {
        if let urlStr = asset.imageUrls?.first, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    thumbnailPlaceholder
                @unknown default:
                    thumbnailPlaceholder
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            thumbnailPlaceholder
                .frame(width: 52, height: 52)
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.studioAccent.opacity(0.08))
            .overlay {
                Image(systemName: "cube")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color.studioAccent.opacity(0.45))
            }
    }
}
