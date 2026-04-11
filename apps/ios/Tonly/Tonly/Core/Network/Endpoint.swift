import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: [String: Any]?

    init(path: String, method: HTTPMethod = .get, body: [String: Any]? = nil) {
        self.path = path
        self.method = method
        self.body = body
    }
}

extension Endpoint {
    static var health: Endpoint {
        Endpoint(path: "/health")
    }


    static func walletBalance(address: String) -> Endpoint {
        Endpoint(path: "/wallet/\(address)")
    }

    static func walletOverview(address: String) -> Endpoint {
        Endpoint(path: "/wallet/\(address)/overview")
    }

    static func walletTransactions(address: String, limit: Int = 20) -> Endpoint {
        Endpoint(path: "/wallet/\(address)/transactions?limit=\(limit)")
    }

    static func walletActivity(address: String, limit: Int = 25) -> Endpoint {
        Endpoint(path: "/wallet/\(address)/activity?limit=\(limit)")
    }

    static func walletJettons(address: String, currency: String = "usd") -> Endpoint {
        Endpoint(path: "/wallet/\(address)/jettons?currency=\(currency)")
    }

    static func walletNFTs(address: String) -> Endpoint {
        Endpoint(path: "/wallet/\(address)/nfts")
    }

    static func rates(tokens: String = "ton", currencies: String = "usd") -> Endpoint {
        Endpoint(path: "/rates?tokens=\(tokens)&currencies=\(currencies)")
    }

    static func walletSeqno(address: String) -> Endpoint {
        Endpoint(path: "/wallet/\(address)/seqno")
    }

    static func sendBoc() -> Endpoint {
        Endpoint(path: "/send", method: .post)
    }

    static func resolveDomain(_ domain: String) -> Endpoint {
        Endpoint(path: "/dns/\(domain)")
    }

    static func chart(token: String = "ton", currency: String = "usd", period: String = "1m") -> Endpoint {
        Endpoint(path: "/rates/chart?token=\(token)&currency=\(currency)&period=\(period)")
    }

    static func swapSimulate(offerAddress: String, askAddress: String, units: String, slippage: String = "0.01") -> Endpoint {
        Endpoint(path: "/swap/simulate?offer_address=\(offerAddress)&ask_address=\(askAddress)&units=\(units)&slippage_tolerance=\(slippage)", method: .post)
    }

    static var swapAssets: Endpoint {
        Endpoint(path: "/swap/assets")
    }
}
