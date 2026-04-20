import Foundation
import TonSwift

struct ServerTimeResponse: Decodable {
    let time: Int64
}

enum TransferSigner {
    static func serverTime() async -> UInt64 {
        do {
            let response: ServerTimeResponse = try await APIClient.shared.request(
                Endpoint(path: "/time")
            )
            return UInt64(response.time)
        } catch {
            return UInt64(Date().timeIntervalSince1970)
        }
    }

    static func timeout(ttl: UInt64 = 120) async -> UInt64 {
        await serverTime() + ttl
    }

    static func signAndBroadcast(
        messages: [MessageRelaxed],
        sendMode: SendMode = .walletDefault()
    ) async throws {
        guard let store = WalletStore.shared.wallet else {
            throw NSError(domain: "transfer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No wallet"])
        }

        let seqnoResponse: SeqnoResponse = try await APIClient.shared.request(
            .walletSeqno(address: WalletStore.shared.apiAddress ?? "")
        )

        let keyPair = try TONWalletManager.getKeyPair()
        let walletId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
        let wallet = WalletV5R1(
            seqno: Int64(seqnoResponse.seqno),
            workchain: 0,
            publicKey: keyPair.publicKey.data,
            walletId: walletId
        )

        let timeoutValue = await timeout()

        let transferData = WalletTransferData(
            seqno: UInt64(seqnoResponse.seqno),
            messages: messages,
            sendMode: sendMode,
            timeout: timeoutValue
        )

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
        let stateInit: StateInit? = seqnoResponse.seqno == 0 ? wallet.stateInit : nil
        let walletAddress = try wallet.address()
        let extMessage = Message.external(to: walletAddress, stateInit: stateInit, body: body)
        let extCell = try Builder().store(extMessage).endCell()
        let boc = try extCell.toBoc().base64EncodedString()

        _ = store
        struct SendResp: Decodable { let hash: String?; let ok: Bool? }
        let _: SendResp = try await APIClient.shared.request(
            Endpoint(path: "/send", method: .post, body: ["boc": boc])
        )
    }

    static func emulate(messages: [MessageRelaxed]) async throws -> EmulateResult {
        let seqnoResponse: SeqnoResponse = try await APIClient.shared.request(
            .walletSeqno(address: WalletStore.shared.apiAddress ?? "")
        )

        let keyPair = try TONWalletManager.getKeyPair()
        let walletId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
        let wallet = WalletV5R1(
            seqno: Int64(seqnoResponse.seqno),
            workchain: 0,
            publicKey: keyPair.publicKey.data,
            walletId: walletId
        )

        let timeoutValue = await timeout()
        let transferData = WalletTransferData(
            seqno: UInt64(seqnoResponse.seqno),
            messages: messages,
            sendMode: .walletDefault(),
            timeout: timeoutValue
        )

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
        let stateInit: StateInit? = seqnoResponse.seqno == 0 ? wallet.stateInit : nil
        let walletAddress = try wallet.address()
        let extMessage = Message.external(to: walletAddress, stateInit: stateInit, body: body)
        let extCell = try Builder().store(extMessage).endCell()
        let boc = try extCell.toBoc().base64EncodedString()

        return try await APIClient.shared.request(
            Endpoint(path: "/send/emulate", method: .post, body: ["boc": boc])
        )
    }
}

struct EmulateResult: Decodable {
    let event: EmulateEvent?
    let trace: EmulateTrace?
}

struct EmulateEvent: Decodable {
    let fee: Int64?
    let extra: Int64?
}

struct EmulateTrace: Decodable {
    let transaction: EmulateTxn?
}

struct EmulateTxn: Decodable {
    let totalFees: Int64?

    enum CodingKeys: String, CodingKey {
        case totalFees = "total_fees"
    }
}
