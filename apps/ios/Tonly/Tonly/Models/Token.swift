import Foundation

struct Token: Codable, Identifiable {
    let id: String
    let name: String
    let symbol: String
    let decimals: Int
    let contractAddress: String
    var balance: Double
    var usdPrice: Double
    var iconURL: URL?

    var usdValue: Double {
        balance * usdPrice
    }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = min(decimals, 6)
        return formatter.string(from: NSNumber(value: balance)) ?? "0"
    }

    static var ton: Token {
        Token(
            id: "ton",
            name: "Toncoin",
            symbol: "TON",
            decimals: 9,
            contractAddress: "",
            balance: 0,
            usdPrice: 0,
            iconURL: URL(string: "https://assets.dedust.io/images/ton.webp")
        )
    }
}
