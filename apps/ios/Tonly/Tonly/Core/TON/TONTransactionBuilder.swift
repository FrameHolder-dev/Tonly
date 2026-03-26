import Foundation
import TonSwift
import BigInt

struct TONTransactionBuilder {
    static func buildTransfer(
        to destination: String,
        amount: UInt64,
        message: String? = nil,
        seqno: Int64
    ) throws -> String {
        let keyPair = try TONWalletManager.getKeyPair()

        let walletId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
        let wallet = WalletV5R1(
            seqno: seqno,
            workchain: 0,
            publicKey: keyPair.publicKey.data,
            walletId: walletId
        )

        let destAddress = try Address.parse(destination)

        let msg: MessageRelaxed
        if let message, !message.isEmpty {
            msg = try .internal(to: destAddress, value: BigUInt(amount), bounce: false, textPayload: message)
        } else {
            msg = .internal(to: destAddress, value: BigUInt(amount), bounce: false)
        }

        let transferData = WalletTransferData(
            seqno: UInt64(seqno),
            messages: [msg],
            sendMode: .walletDefault(),
            timeout: UInt64(Date().timeIntervalSince1970) + 120
        )

        return try signAndBuild(wallet: wallet, transferData: transferData, keyPair: keyPair, seqno: seqno)
    }

    static func buildBatchTransfer(
        transfers: [(to: String, amount: UInt64, message: String?)],
        seqno: Int64
    ) throws -> String {
        let keyPair = try TONWalletManager.getKeyPair()

        let walletId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
        let wallet = WalletV5R1(
            seqno: seqno,
            workchain: 0,
            publicKey: keyPair.publicKey.data,
            walletId: walletId
        )

        let messages: [MessageRelaxed] = try transfers.map { t in
            let dest = try Address.parse(t.to)
            if let msg = t.message, !msg.isEmpty {
                return try .internal(to: dest, value: BigUInt(t.amount), bounce: false, textPayload: msg)
            } else {
                return .internal(to: dest, value: BigUInt(t.amount), bounce: false)
            }
        }

        let transferData = WalletTransferData(
            seqno: UInt64(seqno),
            messages: messages,
            sendMode: .walletDefault(),
            timeout: UInt64(Date().timeIntervalSince1970) + 120
        )

        return try signAndBuild(wallet: wallet, transferData: transferData, keyPair: keyPair, seqno: seqno)
    }

    private static func signAndBuild(wallet: WalletV5R1, transferData: WalletTransferData, keyPair: KeyPair, seqno: Int64) throws -> String {
        let transfer = try wallet.createTransfer(args: transferData)
        let signer = WalletTransferSecretKeySigner(secretKey: keyPair.privateKey.data)
        let signature = try transfer.signMessage(signer: signer)

        let bodyBuilder = Builder()
        switch transfer.signaturePosition {
        case .front:
            try bodyBuilder.store(data: signature)
            try bodyBuilder.store(transfer.signingMessage)
        case .tail:
            try bodyBuilder.store(transfer.signingMessage)
            try bodyBuilder.store(data: signature)
        }

        let body = try bodyBuilder.endCell()
        let stateInit: StateInit? = seqno == 0 ? wallet.stateInit : nil
        let walletAddress = try wallet.address()
        let extMessage = Message.external(to: walletAddress, stateInit: stateInit, body: body)
        let extCell = try Builder().store(extMessage).endCell()

        return try extCell.toBoc().base64EncodedString()
    }

    static func tonToNano(_ ton: Double) -> UInt64 {
        UInt64(ton * 1_000_000_000)
    }
}
