import Foundation
import TonSwift

struct SecureMnemonicClient {
    static func generate() async -> [String] {
        await Task.detached(priority: .userInitiated) {
            Mnemonic.mnemonicNew(wordsCount: 24)
        }.value
    }
}
