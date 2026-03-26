import SwiftUI

struct NFTResponse: Codable {
    let nfts: [NFTAPIItem]
}

struct NFTAPIItem: Codable {
    let address: String
    let name: String
    let description: String
    let imageURL: String
    let collectionName: String
    let collectionAddress: String
    let verified: Bool
    let dns: String?
    let nftType: String

    enum CodingKeys: String, CodingKey {
        case address, name, description, verified, dns
        case imageURL = "image_url"
        case collectionName = "collection_name"
        case collectionAddress = "collection_address"
        case nftType = "nft_type"
    }
}

struct NFTGalleryView: View {
    @State private var store = WalletStore.shared
    @State private var nfts: [NFTItem] = []
    @State private var isLoading = false
    @State private var selectedNFT: NFTItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && nfts.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<6, id: \.self) { _ in
                                SkeletonView(height: 180, cornerRadius: TonlyTheme.cornerRadius)
                            }
                        }
                        .padding(.horizontal, TonlyTheme.padding)
                    }
                } else if nfts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 40))
                            .foregroundStyle(TonlyTheme.surfaceLight)

                        Text("No NFTs Yet")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(TonlyTheme.textPrimary)

                        Text("Your collectibles will appear here")
                            .font(.subheadline)
                            .foregroundStyle(TonlyTheme.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(nfts) { nft in
                                NFTCardView(nft: nft)
                                    .onTapGesture {
                                        selectedNFT = nft
                                        HapticService.selection()
                                    }
                            }
                        }
                        .padding(.horizontal, TonlyTheme.padding)
                        .padding(.top, 8)
                    }
                }
            }
            .background(TonlyTheme.background)
            .navigationTitle("NFTs")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await loadNFTs()
            }
            .sheet(item: $selectedNFT) { nft in
                NFTDetailView(nft: nft)
            }
            .task {
                await loadNFTs()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadNFTs() async {
        guard let address = store.apiAddress else { return }
        isLoading = true

        do {
            let response: NFTResponse = try await APIClient.shared.request(
                .walletNFTs(address: address)
            )
            nfts = response.nfts.map { item in
                NFTItem(
                    id: item.address,
                    name: item.name,
                    description: item.description,
                    imageURL: item.imageURL.isEmpty ? nil : URL(string: item.imageURL),
                    collectionName: item.collectionName.isEmpty ? nil : item.collectionName,
                    ownerAddress: address,
                    contractAddress: item.address,
                    nftType: NFTType(rawValue: item.nftType) ?? .nft,
                    dns: item.dns,
                    isVerified: item.verified
                )
            }
        } catch {}

        isLoading = false
    }
}

struct NFTCardView: View {
    let nft: NFTItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let url = nft.imageURL, !url.absoluteString.isEmpty {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        nftPlaceholder
                    }
                } else {
                    nftPlaceholder
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(nft.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TonlyTheme.textPrimary)
                        .lineLimit(1)

                    if nft.isVerified {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(TonlyTheme.accent)
                    }
                }

                if let collection = nft.collectionName {
                    HStack(spacing: 4) {
                        Text(collection)
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)
                            .lineLimit(1)

                        if !nft.isVerified {
                            Text("Unverified")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(TonlyTheme.warning)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(TonlyTheme.warning.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(TonlyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
    }

    private var nftPlaceholder: some View {
        RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall)
            .fill(TonlyTheme.accent.opacity(0.15))
            .overlay {
                Image(systemName: "globe")
                    .font(.system(size: 32))
                    .foregroundStyle(TonlyTheme.accent)
            }
    }
}
