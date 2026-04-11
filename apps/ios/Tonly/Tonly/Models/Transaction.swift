import Foundation

enum TransactionKind: String, Codable {
    case ton
    case jetton
    case nft
    case swap
    case contractExec
}

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
    var kind: TransactionKind = .ton
    var symbol: String = "TON"
    var iconURL: String? = nil
    var isIncoming: Bool = false

    var formattedAmount: String {
        let sign = isIncoming ? "+" : "-"
        let formatted = String(format: "%.4f", amount).trimmingTrailingZeros()
        return "\(sign)\(formatted) \(symbol)"
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: .now)
    }
}

extension String {
    func trimmingTrailingZeros() -> String {
        guard contains(".") else { return self }
        var s = self
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
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
