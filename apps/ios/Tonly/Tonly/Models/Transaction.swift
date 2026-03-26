import Foundation

struct Transaction: Codable, Identifiable {
    let id: String
    let hash: String
    let timestamp: Date
    let from: String
    let to: String
    let amount: Double
    let fee: Double
    let status: TransactionStatus
    let message: String?

    var isIncoming: Bool {
        guard let myAddr = WalletStore.shared.activeAddress else { return false }
        let dest = to
        let my = myAddr
        if dest == my { return true }
        if dest.count > 6 && my.count > 6 {
            let destCore = dest.dropFirst(2).dropLast(4)
            let myCore = my.dropFirst(2).dropLast(4)
            return destCore == myCore
        }
        return false
    }

    var formattedAmount: String {
        let sign = isIncoming ? "+" : "-"
        return "\(sign)\(amount.tonFormatted) TON"
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: .now)
    }
}

enum TransactionStatus: String, Codable {
    case pending
    case confirmed
    case failed
}

struct TransactionListResponse: Codable {
    let address: String
    let transactions: [TransactionRaw]
}

struct TransactionRaw: Codable {
    let utime: Int?
    let fee: String?
    let inMsg: TxMessage?
    let outMsgs: [TxMessage]?
    let transactionId: TxId?

    enum CodingKeys: String, CodingKey {
        case utime, fee
        case inMsg = "in_msg"
        case outMsgs = "out_msgs"
        case transactionId = "transaction_id"
    }
}

struct TxId: Codable {
    let lt: String?
    let hash: String?
}

struct TxMessage: Codable {
    let source: String?
    let destination: String?
    let value: String?
    let message: String?
}
