import Foundation
import TonSwift
import CryptoKit

struct TonConnectRequest {
    let manifestURL: String
    let clientID: String
    let returnURL: String?
    let items: [ConnectItem]

    struct ConnectItem {
        let name: String
        let payload: String?
    }
}

struct TonConnectManager {
    static func parseURL(_ url: URL) -> TonConnectRequest? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        let params = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        var rString = params["r"] ?? ""
        if rString.isEmpty { return nil }

        if rString.contains("%7B") || rString.contains("%22") {
            rString = rString.removingPercentEncoding ?? rString
        }

        guard let rData = rString.data(using: .utf8),
              let rJson = try? JSONSerialization.jsonObject(with: rData) as? [String: Any],
              let manifestUrl = rJson["manifestUrl"] as? String else {
            return nil
        }

        let id = params["id"] ?? ""
        let ret = params["ret"]

        var items: [TonConnectRequest.ConnectItem] = []
        if let itemsArray = rJson["items"] as? [[String: Any]] {
            for item in itemsArray {
                let name = item["name"] as? String ?? ""
                let payload = item["payload"] as? String
                items.append(.init(name: name, payload: payload))
            }
        }

        return TonConnectRequest(manifestURL: manifestUrl, clientID: id, returnURL: ret, items: items)
    }

    static func buildResponse(request: TonConnectRequest) throws -> [String: Any] {
        let keyPair = try TONWalletManager.getKeyPair()
        let walletId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
        let wallet = WalletV5R1(
            seqno: 0,
            workchain: 0,
            publicKey: keyPair.publicKey.data,
            walletId: walletId
        )

        let address = try wallet.address()
        let friendlyAddress = address.toFriendly(testOnly: false, bounceable: false).toString()

        var responseItems: [[String: Any]] = []

        for item in request.items {
            switch item.name {
            case "ton_addr":
                let stateInitCell = try Builder().store(wallet.stateInit).endCell()
                let stateInitBoc = try stateInitCell.toBoc().base64EncodedString()

                responseItems.append([
                    "name": "ton_addr",
                    "address": address.toRaw(),
                    "network": "-239",
                    "publicKey": keyPair.publicKey.data.hexString(),
                    "walletStateInit": stateInitBoc
                ])

            case "ton_proof":
                if let payload = item.payload {
                    let proof = try generateTonProof(
                        address: address,
                        payload: payload,
                        privateKey: keyPair.privateKey.data
                    )
                    responseItems.append([
                        "name": "ton_proof",
                        "proof": proof
                    ])
                }
            default:
                break
            }
        }

        return [
            "id": request.clientID,
            "event": "connect",
            "payload": [
                "items": responseItems,
                "device": [
                    "platform": "iphone",
                    "appName": "Tonly",
                    "appVersion": "1.0.0",
                    "maxProtocolVersion": 2,
                    "features": ["SendTransaction"]
                ]
            ]
        ]
    }

    private static func generateTonProof(address: Address, payload: String, privateKey: Data) throws -> [String: Any] {
        let timestamp = Int(Date().timeIntervalSince1970)
        let domain = "tonly.one"
        let domainLength = UInt32(domain.utf8.count)

        var message = Data()
        message.append(contentsOf: "ton-proof-item-v2/".utf8)

        let workchain = Int32(address.workchain)
        withUnsafeBytes(of: workchain.littleEndian) { message.append(contentsOf: $0) }
        message.append(address.hash)

        withUnsafeBytes(of: domainLength.littleEndian) { message.append(contentsOf: $0) }
        message.append(Data(domain.utf8))

        let ts = UInt64(timestamp)
        withUnsafeBytes(of: ts.littleEndian) { message.append(contentsOf: $0) }
        message.append(Data(payload.utf8))

        let hash = SHA256.hash(data: message)
        let prefixedMessage = Data("ton-connect".utf8) + Data(SHA256.hash(data: Data([0xff, 0xff]) + Data("ton-connect".utf8) + Data(hash)))

        let finalHash = Data(SHA256.hash(data: prefixedMessage))

        let seed = privateKey.prefix(32)
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let signature = try signingKey.signature(for: finalHash)

        return [
            "timestamp": timestamp,
            "domain": [
                "lengthBytes": domainLength,
                "value": domain
            ],
            "payload": payload,
            "signature": signature.base64EncodedString()
        ]
    }
}
