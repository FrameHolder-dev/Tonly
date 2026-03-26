import SwiftUI

enum AppTab: String, CaseIterable {
    case wallet
    case nfts
    case transactions
    case settings

    var title: String {
        switch self {
        case .wallet: "Wallet"
        case .nfts: "NFTs"
        case .transactions: "Activity"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .wallet: "wallet.bifold"
        case .nfts: "square.grid.2x2"
        case .transactions: "arrow.up.arrow.down"
        case .settings: "gearshape"
        }
    }
}
