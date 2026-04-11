import Foundation

struct NFTCollection: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let imageURL: URL?
    var items: [NFTItem]
}

enum NFTType: String, Codable {
    case nft
    case dns
    case anonymousNumber = "anonymous_number"
    case username
    case gift
}

struct NFTItem: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let imageURL: URL?
    let animationURL: URL?
    let collectionName: String?
    let ownerAddress: String
    let contractAddress: String
    var nftType: NFTType
    var dns: String?
    var isVerified: Bool
    var isUsedAsTheme: Bool
    var isUsedAsAvatar: Bool

    var displayURL: URL? { animationURL ?? imageURL }
    var isAnimated: Bool { animationURL != nil }

    init(id: String, name: String, description: String? = nil, imageURL: URL? = nil,
         animationURL: URL? = nil, collectionName: String? = nil, ownerAddress: String,
         contractAddress: String, nftType: NFTType = .nft, dns: String? = nil,
         isVerified: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.animationURL = animationURL
        self.collectionName = collectionName
        self.ownerAddress = ownerAddress
        self.contractAddress = contractAddress
        self.nftType = nftType
        self.dns = dns
        self.isVerified = isVerified
        self.isUsedAsTheme = false
        self.isUsedAsAvatar = false
    }
}
