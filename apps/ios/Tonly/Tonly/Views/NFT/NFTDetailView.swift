import SwiftUI
import TonSwift
import BigInt

struct NFTDetailView: View {
    let nft: NFTItem
    @Environment(\.dismiss) private var dismiss
    @State private var showWeb = false
    @State private var webURL: URL?
    @State private var showSendNFT = false
    @State private var sendAddress = ""
    @State private var isSending = false
    @State private var sendError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        if let animURL = nft.animationURL {
                            AnimatedImageView(url: animURL, staticFallback: nft.imageURL)
                                .aspectRatio(1, contentMode: .fit)
                        } else if let url = nft.imageURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                nftPlaceholder
                            }
                        } else {
                            nftPlaceholder
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    .padding(.horizontal, TonlyTheme.padding)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(nft.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(TonlyTheme.textPrimary)

                        if let collection = nft.collectionName {
                            Text(collection)
                                .font(.subheadline)
                                .foregroundStyle(TonlyTheme.accent)
                        }

                        if let description = nft.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(TonlyTheme.textSecondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, TonlyTheme.padding)

                    actionButtons

                    VStack(spacing: 0) {
                        detailRow("Owner", value: nft.ownerAddress.shortAddress)
                        Divider().background(TonlyTheme.surfaceLight)
                        detailRow("Contract", value: nft.contractAddress.shortAddress)
                        if let dns = nft.dns, !dns.isEmpty {
                            Divider().background(TonlyTheme.surfaceLight)
                            detailRow("Domain", value: dns)
                        }
                    }
                    .background(TonlyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    .padding(.horizontal, TonlyTheme.padding)
                }
                .padding(.top, 8)
            }
            .background(TonlyTheme.background)
            .navigationTitle("NFT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showWeb) {
                if let url = webURL {
                    WebBrowserView(url: url)
                }
            }
            .sheet(isPresented: $showSendNFT) {
                sendNFTSheet
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sendNFTSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(nft.name)
                        .font(.headline)
                        .foregroundStyle(TonlyTheme.textPrimary)
                    if let collection = nft.collectionName {
                        Text(collection)
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient Address")
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.textSecondary)

                    HStack {
                        TextField("UQ... or EQ...", text: $sendAddress)
                            .font(.body)
                            .foregroundStyle(TonlyTheme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button("Paste") {
                            if let clip = UIPasteboard.general.string {
                                sendAddress = clip
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TonlyTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(TonlyTheme.surfaceLight)
                        .clipShape(Capsule())
                    }
                    .padding(14)
                    .background(TonlyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))
                }
                .padding(.horizontal, TonlyTheme.padding)

                if let error = sendError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.destructive)
                        .padding(.horizontal, TonlyTheme.padding)
                }

                Spacer()

                Button {
                    Task { await sendNFT() }
                } label: {
                    Group {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text("Send NFT")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(sendAddress.isValidTONAddress ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                }
                .disabled(!sendAddress.isValidTONAddress || isSending)
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.bottom, 16)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Send NFT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showSendNFT = false
                        sendAddress = ""
                        sendError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sendNFT() async {
        guard !sendAddress.isEmpty, sendAddress.isValidTONAddress else {
            sendError = "Invalid address"
            return
        }

        let auth = await BiometricService.authenticate(reason: "Confirm NFT transfer")
        guard auth else {
            sendError = "Authentication failed"
            return
        }

        do {
            let store = WalletStore.shared
            let seqnoResponse: SeqnoResponse = try await APIClient.shared.request(
                .walletSeqno(address: store.apiAddress ?? "")
            )

            let nftAddress = try TonSwift.Address.parse(nft.contractAddress)
            let destAddress = try TonSwift.Address.parse(sendAddress)
            let myAddress = try TonSwift.Address.parse(store.activeAddress ?? "")

            let forwardPayload = try Builder().store(int: 0, bits: 32).endCell()

            let transferBody = try Builder()
                .store(uint: 0x5fcc3d14, bits: 32)
                .store(uint: 0, bits: 64)
                .store(destAddress)
                .store(myAddress)
                .store(bit: false)
                .store(Coins(rawValue: BigUInt(50000000))!)
                .store(bit: true)
                .store(ref: forwardPayload)
                .endCell()

            let msg = MessageRelaxed.internal(
                to: nftAddress,
                value: BigUInt(100000000),
                bounce: true,
                body: transferBody
            )

            let keyPair = try TONWalletManager.getKeyPair()
            let walletId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
            let wallet = WalletV5R1(
                seqno: Int64(seqnoResponse.seqno),
                workchain: 0,
                publicKey: keyPair.publicKey.data,
                walletId: walletId
            )

            let transferData = WalletTransferData(
                seqno: UInt64(seqnoResponse.seqno),
                messages: [msg],
                sendMode: .walletDefault(),
                timeout: UInt64(Date().timeIntervalSince1970) + 120
            )

            let transfer = try wallet.createTransfer(args: transferData)
            let signer = WalletTransferSecretKeySigner(secretKey: keyPair.privateKey.data)
            let signature = try transfer.signMessage(signer: signer)

            let bodyBuilder = Builder()
            let signingCell = try transfer.signingMessage.endCell()
            try bodyBuilder.store(signingCell.toBuilder())
            try bodyBuilder.store(data: signature)

            let body = try bodyBuilder.endCell()
            let stateInit: StateInit? = seqnoResponse.seqno == 0 ? wallet.stateInit : nil
            let walletAddress = try wallet.address()
            let extMessage = Message.external(to: walletAddress, stateInit: stateInit, body: body)
            let extCell = try Builder().store(extMessage).endCell()
            let boc = try extCell.toBoc().base64EncodedString()

            struct SendResp: Decodable { let hash: String?; let ok: Bool? }
            let _: SendResp = try await APIClient.shared.request(
                Endpoint(path: "/send", method: .post, body: ["boc": boc])
            )

            HapticService.transactionSent()
            sendAddress = ""
            dismiss()
        } catch {
            sendError = "Failed: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 10) {
            switch nft.nftType {
            case .dns:
                HStack(spacing: 10) {
                    actionButton("Manage", icon: "gear") {
                        webURL = URL(string: "https://tonviewer.com/\(nft.contractAddress)")
                        showWeb = true
                    }
                    actionButton("Renew", icon: "arrow.clockwise") {
                        webURL = URL(string: "https://tonviewer.com/\(nft.contractAddress)")
                        showWeb = true
                    }
                }
            case .anonymousNumber, .username:
                actionButton("Manage on Fragment", icon: "arrow.up.right") {
                    webURL = URL(string: "https://fragment.com")
                    showWeb = true
                }
            case .gift:
                actionButton("View on Fragment", icon: "gift") {
                    webURL = URL(string: "https://fragment.com")
                    showWeb = true
                }
            case .nft:
                actionButton("View on Tonviewer", icon: "sparkles") {
                    webURL = URL(string: "https://tonviewer.com/\(nft.contractAddress)")
                    showWeb = true
                }
            }

            Button {
                showSendNFT = true
                HapticService.impact()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Send NFT")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TonlyTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
            }
        }
        .padding(.horizontal, TonlyTheme.padding)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(TonlyTheme.surface)
            .foregroundStyle(TonlyTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
        }
    }

    private var nftPlaceholder: some View {
        RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius)
            .fill(TonlyTheme.accent.opacity(0.15))
            .frame(height: 300)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: nft.nftType == .dns ? "globe" : "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(TonlyTheme.accent)
                    Text(nft.name)
                        .font(.headline)
                        .foregroundStyle(TonlyTheme.accent)
                }
            }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(TonlyTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TonlyTheme.textPrimary)
        }
        .padding(.horizontal, TonlyTheme.padding)
        .padding(.vertical, 14)
    }
}
