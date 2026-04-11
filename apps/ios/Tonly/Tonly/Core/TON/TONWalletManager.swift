import Foundation
import TonSwift

struct TONWalletManager {
    private static let walletIdsKey = "wallet_ids"
    private static let activeWalletIdKey = "active_wallet_id"
    private static let walletNamesKey = "wallet_names"
    private static let keychainKeys = ["seed_phrase", "wallet_address", "raw_address", "public_key", "private_key"]

    static func validateMnemonic(_ words: [String]) -> Bool {
        Mnemonic.mnemonicValidate(mnemonicArray: words)
    }

    static func createWallet(seedPhrase: [String], walletId: String = UUID().uuidString) throws -> TONWalletData {
        let keyPair = try Mnemonic.mnemonicToPrivateKey(mnemonicArray: seedPhrase)

        let wId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
        let wallet = WalletV5R1(
            seqno: 0,
            workchain: 0,
            publicKey: keyPair.publicKey.data,
            walletId: wId
        )

        let address = try wallet.address()
        let friendlyAddress = address.toFriendly(testOnly: false, bounceable: false).toString()
        let rawAddr = address.toRaw()

        let prefix = "\(walletId)_"
        let phraseData = seedPhrase.joined(separator: " ").data(using: .utf8)!
        try KeychainManager.save(key: "\(prefix)seed_phrase", data: phraseData)
        try KeychainManager.save(key: "\(prefix)wallet_address", data: friendlyAddress.data(using: .utf8)!)
        try KeychainManager.save(key: "\(prefix)raw_address", data: rawAddr.data(using: .utf8)!)
        try KeychainManager.save(key: "\(prefix)public_key", data: keyPair.publicKey.data)
        try KeychainManager.save(key: "\(prefix)private_key", data: keyPair.privateKey.data)

        let defaults = UserDefaults.standard
        var ids = defaults.stringArray(forKey: walletIdsKey) ?? []
        if !ids.contains(walletId) {
            ids.append(walletId)
        }
        defaults.set(ids, forKey: walletIdsKey)
        defaults.set(walletId, forKey: activeWalletIdKey)

        return TONWalletData(
            walletId: walletId,
            address: friendlyAddress,
            publicKey: keyPair.publicKey.data.hexString(),
            rawAddress: rawAddr
        )
    }

    static func importWallet(seedPhrase: [String], walletId: String = UUID().uuidString) throws -> TONWalletData {
        guard validateMnemonic(seedPhrase) else {
            throw TONError.invalidSeed
        }
        return try createWallet(seedPhrase: seedPhrase, walletId: walletId)
    }

    static func getKeyPair() throws -> KeyPair {
        guard let activeId = getActiveWalletId() else {
            throw TONError.noWallet
        }
        let prefix = "\(activeId)_"
        guard let seedData = try? KeychainManager.read(key: "\(prefix)seed_phrase"),
              let phrase = String(data: seedData, encoding: .utf8) else {
            throw TONError.noWallet
        }
        let words = phrase.components(separatedBy: " ")
        return try Mnemonic.mnemonicToPrivateKey(mnemonicArray: words)
    }

    static func getStoredWallet() -> TONWalletData? {
        guard let activeId = getActiveWalletId() else { return nil }
        return getStoredWallet(id: activeId)
    }

    static func getStoredWallet(id: String) -> TONWalletData? {
        let prefix = "\(id)_"
        guard let addressData = try? KeychainManager.read(key: "\(prefix)wallet_address"),
              let address = String(data: addressData, encoding: .utf8) else {
            return nil
        }
        let pubKey = (try? KeychainManager.read(key: "\(prefix)public_key"))?.hexString() ?? ""
        let rawAddr = (try? KeychainManager.read(key: "\(prefix)raw_address")).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return TONWalletData(walletId: id, address: address, publicKey: pubKey, rawAddress: rawAddr)
    }

    static func deleteWallet() {
        guard let activeId = getActiveWalletId() else { return }
        deleteWallet(id: activeId)

        let defaults = UserDefaults.standard
        var ids = defaults.stringArray(forKey: walletIdsKey) ?? []
        ids.removeAll { $0 == activeId }
        defaults.set(ids, forKey: walletIdsKey)

        var names = defaults.dictionary(forKey: walletNamesKey) as? [String: String] ?? [:]
        names.removeValue(forKey: activeId)
        defaults.set(names, forKey: walletNamesKey)

        if let nextId = ids.first {
            defaults.set(nextId, forKey: activeWalletIdKey)
        } else {
            defaults.removeObject(forKey: activeWalletIdKey)
            PINManager.remove()
        }
    }

    static func deleteWallet(id: String) {
        let prefix = "\(id)_"
        for key in keychainKeys {
            try? KeychainManager.delete(key: "\(prefix)\(key)")
        }
    }

    static func hasWallet() -> Bool {
        let ids = UserDefaults.standard.stringArray(forKey: walletIdsKey) ?? []
        return !ids.isEmpty
    }

    static func getAllWalletIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: walletIdsKey) ?? []
    }

    static func getActiveWalletId() -> String? {
        UserDefaults.standard.string(forKey: activeWalletIdKey)
    }

    static func setActiveWalletId(_ id: String) {
        UserDefaults.standard.set(id, forKey: activeWalletIdKey)
    }

    static func getWalletName(id: String) -> String {
        let names = UserDefaults.standard.dictionary(forKey: walletNamesKey) as? [String: String] ?? [:]
        return names[id] ?? "Wallet"
    }

    static func setWalletName(id: String, name: String) {
        var names = UserDefaults.standard.dictionary(forKey: walletNamesKey) as? [String: String] ?? [:]
        names[id] = name
        UserDefaults.standard.set(names, forKey: walletNamesKey)
    }

    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        let existingIds = defaults.stringArray(forKey: walletIdsKey) ?? []
        guard existingIds.isEmpty else { return }

        guard KeychainManager.exists(key: "wallet_address") else { return }

        let walletId = UUID().uuidString
        let prefix = "\(walletId)_"

        for key in keychainKeys {
            if let data = try? KeychainManager.read(key: key) {
                try? KeychainManager.save(key: "\(prefix)\(key)", data: data)
                try? KeychainManager.delete(key: key)
            }
        }

        defaults.set([walletId], forKey: walletIdsKey)
        defaults.set(walletId, forKey: activeWalletIdKey)
        defaults.set([walletId: "Main Wallet"], forKey: walletNamesKey)

        defaults.removeObject(forKey: "wallet_addresses")
        defaults.removeObject(forKey: "wallet_names")
    }
}

struct TONWalletData {
    let walletId: String
    let address: String
    let publicKey: String
    let rawAddress: String
}

enum TONError: Error {
    case invalidSeed
    case noWallet
    case signingFailed
    case networkError
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(hexString: String) {
        let clean = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        guard clean.count % 2 == 0 else { return nil }
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
