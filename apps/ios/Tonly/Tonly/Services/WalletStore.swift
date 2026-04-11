import Foundation
import SwiftUI
import TonSwift

struct JettonsResponse: Codable {
    let jettons: [JettonData]
}

struct JettonData: Codable {
    let address: String
    let name: String
    let symbol: String
    let decimals: Int
    let balance: String
    let imageURL: String
    let usdPrice: Double
    let usdValue: Double
    let verified: Bool

    enum CodingKeys: String, CodingKey {
        case address, name, symbol, decimals, balance, verified
        case imageURL = "image_url"
        case usdPrice = "usd_price"
        case usdValue = "usd_value"
    }
}

struct ActivityResponse: Codable {
    let activity: [ActivityItem]
}

struct ActivityItem: Codable {
    let id: String
    let hash: String
    let timestamp: Int64
    let kind: String
    let status: String
    let isIncoming: Bool
    let from: String
    let to: String
    let amount: Double
    let symbol: String
    let iconURL: String?
    let comment: String

    enum CodingKeys: String, CodingKey {
        case id, hash, timestamp, kind, status, from, to, amount, symbol, comment
        case isIncoming = "is_incoming"
        case iconURL = "icon_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        hash = try c.decode(String.self, forKey: .hash)
        timestamp = try c.decode(Int64.self, forKey: .timestamp)
        kind = try c.decode(String.self, forKey: .kind)
        status = try c.decode(String.self, forKey: .status)
        isIncoming = try c.decode(Bool.self, forKey: .isIncoming)
        from = try c.decodeIfPresent(String.self, forKey: .from) ?? ""
        to = try c.decodeIfPresent(String.self, forKey: .to) ?? ""
        amount = try c.decode(Double.self, forKey: .amount)
        symbol = try c.decode(String.self, forKey: .symbol)
        iconURL = try c.decodeIfPresent(String.self, forKey: .iconURL)
        comment = try c.decodeIfPresent(String.self, forKey: .comment) ?? ""
    }
}

struct RatesResponse: Codable {
    let rates: [String: RateData]?
}

struct RateData: Codable {
    let prices: [String: Double]?
    let diff24h: [String: String]?

    enum CodingKeys: String, CodingKey {
        case prices
        case diff24h = "diff_24h"
    }
}

@Observable
final class WalletStore {
    static let shared = WalletStore()

    var wallet: Wallet?
    var transactions: [Transaction] = []
    var isLoading = false
    var error: String?
    var tonPrice: Double = 0
    var tonPriceChange24h: Double = 0

    var activeAddress: String? {
        wallet?.address
    }

    var apiAddress: String? {
        if let raw = wallet?.rawAddress, !raw.isEmpty {
            return raw
        }
        guard let addr = wallet?.address else { return nil }
        if let parsed = try? TonSwift.Address.parse(addr) {
            return parsed.toRaw()
        }
        return addr
    }

    var balance: Double {
        wallet?.balance ?? 0
    }

    private init() {}

    func loadWallet() async {
        guard let address = apiAddress else { return }
        isLoading = true
        error = nil

        async let balanceTask: () = loadBalance(address: address)
        async let ratesTask: () = loadRates()
        async let jettonsTask: () = loadJettons(address: address)

        await balanceTask
        await ratesTask
        await jettonsTask

        if let bal = wallet?.balance {
            let tonValue = bal * tonPrice
            let jettonValue = (wallet?.tokens ?? [])
                .filter { $0.id != "ton" }
                .reduce(0.0) { $0 + $1.usdValue }
            wallet?.usdBalance = tonValue + jettonValue
            if let idx = wallet?.tokens.firstIndex(where: { $0.id == "ton" }) {
                wallet?.tokens[idx].usdPrice = tonPrice
            }
        }

        isLoading = false
    }

    private func loadBalance(address: String) async {
        do {
            let response: WalletBalanceResponse = try await APIClient.shared.request(
                .walletBalance(address: address)
            )
            let bal = Double.fromNanoTON(response.balance)
            wallet?.balance = bal
            if let idx = wallet?.tokens.firstIndex(where: { $0.id == "ton" }) {
                wallet?.tokens[idx].balance = bal
            }
        } catch {
            self.error = "Failed to load balance"
        }
    }

    private func loadRates() async {
        let currency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
        let currencyLower = currency.lowercased()
        do {
            let response: RatesResponse = try await APIClient.shared.request(
                .rates(tokens: "ton", currencies: currencyLower)
            )
            if let tonRates = response.rates?["TON"] {
                tonPrice = tonRates.prices?[currency] ?? tonRates.prices?["USD"] ?? 0
                if let diff = tonRates.diff24h?[currency] ?? tonRates.diff24h?["USD"], let val = Double(diff) {
                    tonPriceChange24h = val
                }
            }
        } catch {}
    }

    private func loadJettons(address: String) async {
        let currency = (UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD").lowercased()
        do {
            let response: JettonsResponse = try await APIClient.shared.request(
                .walletJettons(address: address, currency: currency)
            )
            let jettonTokens = response.jettons.map { j in
                Token(
                    id: j.address,
                    name: j.name,
                    symbol: j.symbol,
                    decimals: j.decimals,
                    contractAddress: j.address,
                    balance: Double(j.balance) ?? 0,
                    usdPrice: j.usdPrice,
                    iconURL: URL(string: j.imageURL)
                )
            }
            if let tonToken = wallet?.tokens.first(where: { $0.id == "ton" }) {
                wallet?.tokens = [tonToken] + jettonTokens
            }
        } catch {}
    }

    func loadTransactions() async {
        guard let address = apiAddress else { return }

        do {
            let response: ActivityResponse = try await APIClient.shared.request(
                .walletActivity(address: address)
            )
            transactions = response.activity.map { item in
                var tx = Transaction(
                    id: item.id,
                    hash: item.hash,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(item.timestamp)),
                    from: item.from,
                    to: item.to,
                    amount: item.amount,
                    fee: 0,
                    status: item.status == "ok" ? .confirmed : .failed,
                    message: item.comment.isEmpty ? nil : item.comment
                )
                tx.kind = TransactionKind(rawValue: item.kind) ?? .ton
                tx.symbol = item.symbol
                tx.iconURL = item.iconURL
                tx.isIncoming = item.isIncoming
                return tx
            }
        } catch {
            self.error = "Failed to load transactions"
        }
    }

    var allWalletIds: [String] {
        TONWalletManager.getAllWalletIds()
    }

    func setWallet(from data: TONWalletData, name: String = "Main Wallet") {
        TONWalletManager.setWalletName(id: data.walletId, name: name)
        var w = Wallet(address: data.address, rawAddress: data.rawAddress, name: name)
        w.tokens = [.ton]
        wallet = w
        Task { await loadWallet() }
    }

    func hasWallet() -> Bool {
        TONWalletManager.hasWallet()
    }

    func restoreWallet() {
        guard let activeId = TONWalletManager.getActiveWalletId(),
              let walletData = TONWalletManager.getStoredWallet() else { return }
        let name = TONWalletManager.getWalletName(id: activeId)
        var w = Wallet(address: walletData.address, rawAddress: walletData.rawAddress, name: name)
        w.tokens = [.ton]
        wallet = w
    }

    func switchWallet(id: String) {
        TONWalletManager.setActiveWalletId(id)
        guard let walletData = TONWalletManager.getStoredWallet(id: id) else { return }
        let name = TONWalletManager.getWalletName(id: id)
        var w = Wallet(address: walletData.address, rawAddress: walletData.rawAddress, name: name)
        w.tokens = [.ton]
        wallet = w
        transactions = []
        Task { await loadWallet() }
    }
}
