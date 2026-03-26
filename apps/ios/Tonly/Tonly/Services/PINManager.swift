import Foundation
import CryptoKit

struct PINManager {
    private static let storageKey = "user_pin_hash"

    static func store(_ code: String) {
        let digest = SHA256.hash(data: Data(code.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        guard let data = hex.data(using: .utf8) else { return }
        try? KeychainManager.save(key: storageKey, data: data)
    }

    static func check(_ code: String) -> Bool {
        guard let stored = try? KeychainManager.read(key: storageKey),
              let storedHex = String(data: stored, encoding: .utf8) else {
            return false
        }
        let digest = SHA256.hash(data: Data(code.utf8))
        let inputHex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return inputHex == storedHex
    }

    static var isConfigured: Bool {
        KeychainManager.exists(key: storageKey)
    }

    static func remove() {
        try? KeychainManager.delete(key: storageKey)
    }
}
