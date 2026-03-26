import Foundation

struct Wallet: Codable, Identifiable {
    let id: String
    let address: String
    var rawAddress: String?
    var name: String
    var balance: Double
    var usdBalance: Double
    var tokens: [Token]
    var isActive: Bool

    init(address: String, rawAddress: String? = nil, name: String = "Main Wallet") {
        self.id = address
        self.address = address
        self.rawAddress = rawAddress
        self.name = name
        self.balance = 0
        self.usdBalance = 0
        self.tokens = []
        self.isActive = true
    }
}

struct WalletBalanceResponse: Codable {
    let address: String
    let balance: String
}
