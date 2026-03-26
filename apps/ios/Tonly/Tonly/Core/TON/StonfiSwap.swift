import Foundation
import TonSwift
import BigInt

enum STONFI_CONSTANTS {
    enum SWAP_TON_TO_JETTON {
        static let ForwardGasAmount = BigUInt(300000000)
    }
    enum SWAP_JETTON_TO_JETTON {
        static let ForwardGasAmount = BigUInt(240000000)
        static let GasAmount = BigUInt(300000000)
    }
}

struct StonfiSwapMessage {
    static let SWAP_OP = BigUInt(0x25938561)

    static func internalMessage(
        userWalletAddress: Address,
        minAskAmount: BigUInt,
        offerAmount: BigUInt,
        jettonFromWalletAddress: Address,
        jettonToWalletAddress: Address,
        forwardAmount: BigUInt,
        attachedAmount: BigUInt
    ) throws -> MessageRelaxed {
        let swapBody = try Builder()
            .store(uint: SWAP_OP, bits: 32)
            .store(jettonToWalletAddress)
            .store(Coins(rawValue: minAskAmount)!)
            .store(userWalletAddress)
            .endCell()

        let transferBody = try Builder()
            .store(uint: 0xf8a7ea5, bits: 32)
            .store(uint: 0, bits: 64)
            .store(Coins(rawValue: offerAmount)!)
            .store(jettonFromWalletAddress)
            .store(userWalletAddress)
            .store(bit: false)
            .store(Coins(rawValue: forwardAmount)!)
            .store(bit: true)
            .store(ref: swapBody)
            .endCell()

        return .internal(
            to: jettonFromWalletAddress,
            value: attachedAmount,
            bounce: true,
            body: transferBody
        )
    }
}
