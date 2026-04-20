import SwiftUI
import TonSwift
import BigInt

struct JettonCustomPayloadResponse: Decodable {
    let customPayload: String?
    let stateInit: String?

    enum CodingKeys: String, CodingKey {
        case customPayload = "custom_payload"
        case stateInit = "state_init"
    }
}

struct SendView: View {
    var prefillAddress: String = ""
    var prefillToken: Token? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var amount = ""
    @State private var comment = ""
    @State private var isSending = false
    @State private var error: String?
    @State private var showScanner = false
    @State private var showSuccess = false
    @State private var selectedToken: Token = .ton
    @State private var showTokenPicker = false
    private let store = WalletStore.shared

    var amountValue: Double { Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var isSelfSend: Bool {
        guard let my = store.activeAddress else { return false }
        return address.trimmingCharacters(in: .whitespaces) == my
    }
    var tokenBalance: Double {
        if selectedToken.id == "ton" { return store.balance }
        return selectedToken.balance
    }
    var exceedsBalance: Bool { amountValue > tokenBalance }
    var isValid: Bool {
        address.isValidTONAddress && amountValue > 0 && !isSelfSend && !exceedsBalance
    }
    var buttonTitle: String {
        if address.isEmpty || amount.isEmpty { return "Continue" }
        if isSelfSend { return "Cannot send to yourself" }
        if exceedsBalance { return "Insufficient balance" }
        if !address.isValidTONAddress { return "Invalid address" }
        return "Continue"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    TextField("Address or name", text: $address)
                        .font(.body)
                        .foregroundStyle(TonlyTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Paste") {
                        if let clip = UIPasteboard.general.string {
                            address = clip
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TonlyTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TonlyTheme.surfaceLight)
                    .clipShape(Capsule())

                    Button { showScanner = true } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundStyle(TonlyTheme.accent)
                    }
                }
                .padding(14)
                .background(TonlyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))

                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundStyle(TonlyTheme.textSecondary)

                            TextField("0", text: $amount)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .foregroundStyle(TonlyTheme.textPrimary)
                        }

                        Spacer()

                        Button { showTokenPicker = true } label: {
                            HStack(spacing: 6) {
                                if let url = selectedToken.iconURL {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFit()
                                    } placeholder: {
                                        Circle().fill(TonlyTheme.surface)
                                    }
                                    .frame(width: 22, height: 22)
                                    .clipShape(Circle())
                                }
                                Text(selectedToken.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TonlyTheme.textPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(TonlyTheme.textSecondary)
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 10)
                            .padding(.vertical, 6)
                            .background(TonlyTheme.surfaceLight)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(TonlyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))

                    HStack {
                        let usd = amountValue * selectedToken.usdPrice
                        Text("\(usd.usdFormatted)")
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)

                        Spacer()

                        Text("Available \(String(format: "%.4f", tokenBalance).trimmingTrailingZeros()) \(selectedToken.symbol)")
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)

                        Button("MAX") {
                            let fee: Double = selectedToken.id == "ton" ? 0.065 : 0
                            let maxAmount = max(tokenBalance - fee, 0)
                            amount = String(format: "%.4f", maxAmount)
                            HapticService.selection()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TonlyTheme.accent)
                    }
                }

                HStack {
                    TextField("Comment", text: $comment)
                        .font(.body)
                        .foregroundStyle(TonlyTheme.textPrimary)

                    Button("Paste") {
                        if let clip = UIPasteboard.general.string {
                            comment = clip
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

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.destructive)
                }

                Spacer()

                Button {
                    Task { await send() }
                } label: {
                    Group {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text(buttonTitle)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                }
                .disabled(!isValid || isSending)
            }
            .padding(TonlyTheme.padding)
            .background(TonlyTheme.background)
            .navigationTitle("Send")
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
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !prefillAddress.isEmpty {
                address = prefillAddress
            }
            if let t = prefillToken {
                selectedToken = t
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView { scanned in
                address = scanned
                showScanner = false
            }
        }
        .sheet(isPresented: $showTokenPicker) {
            tokenPicker
        }
    }

    private var tokenPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array((store.wallet?.tokens ?? []).filter { $0.id == "ton" || $0.balance > 0 }.enumerated()), id: \.element.id) { index, token in
                        Button {
                            selectedToken = token
                            showTokenPicker = false
                            HapticService.selection()
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: token.iconURL) { img in
                                    img.resizable().scaledToFit()
                                } placeholder: {
                                    Circle().fill(TonlyTheme.surfaceLight)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(token.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(TonlyTheme.textPrimary)
                                    Text("\(String(format: "%.4f", token.balance).trimmingTrailingZeros()) \(token.symbol)")
                                        .font(.caption)
                                        .foregroundStyle(TonlyTheme.textSecondary)
                                }

                                Spacer()

                                if token.id == selectedToken.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(TonlyTheme.accent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(TonlyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.top, 8)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Select Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func send() async {
        let authenticated = await BiometricService.authenticate(reason: "Confirm transaction")
        guard authenticated else {
            error = "Authentication failed"
            return
        }

        isSending = true
        error = nil

        do {
            let destAddress = try Address.parse(address)
            let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)

            let message: MessageRelaxed

            if selectedToken.id == "ton" {
                let nanoAmount = BigUInt(UInt64(amountValue * 1_000_000_000))
                if !trimmedComment.isEmpty {
                    message = try .internal(
                        to: destAddress,
                        value: nanoAmount,
                        bounce: false,
                        textPayload: trimmedComment
                    )
                } else {
                    message = .internal(
                        to: destAddress,
                        value: nanoAmount,
                        bounce: false
                    )
                }
            } else {
                let jettonMaster = try Address.parse(selectedToken.contractAddress)
                let myAddress = try Address.parse(store.activeAddress ?? "")
                let multiplier = pow(10.0, Double(selectedToken.decimals))
                let rawAmount = BigInt(UInt64(amountValue * multiplier))

                var customPayload: Cell?
                var stateInit: StateInit?
                if let payload = try await fetchJettonPayload(jetton: selectedToken.contractAddress) {
                    if let hex = payload.customPayload, let data = Data(hexString: hex) {
                        let cells = try Cell.fromBoc(src: data)
                        customPayload = cells.first
                    }
                    if let hex = payload.stateInit, let data = Data(hexString: hex) {
                        let cells = try Cell.fromBoc(src: data)
                        if let root = cells.first {
                            stateInit = try root.beginParse().loadType() as StateInit
                        }
                    }
                }

                message = try JettonTransferMessage.internalMessage(
                    jettonAddress: jettonMaster,
                    amount: rawAmount,
                    bounce: true,
                    to: destAddress,
                    from: myAddress,
                    comment: trimmedComment.isEmpty ? nil : trimmedComment,
                    customPayload: customPayload,
                    stateInit: stateInit
                )
                _ = message
            }

            try await TransferSigner.signAndBroadcast(messages: [message])

            HapticService.transactionSent()
            try? await Task.sleep(for: .seconds(3))
            await store.loadWallet()
            await store.loadTransactions()
            dismiss()
        } catch let err {
            self.error = "Failed: \(err.localizedDescription)"
            isSending = false
        }
    }

    private func fetchJettonPayload(jetton: String) async throws -> JettonCustomPayloadResponse? {
        guard let myAddress = store.apiAddress else { return nil }
        do {
            let response: JettonCustomPayloadResponse = try await APIClient.shared.request(
                .jettonPayload(jetton: jetton, address: myAddress)
            )
            return response
        } catch {
            return nil
        }
    }
}

struct SeqnoResponse: Decodable {
    let seqno: Int
}

struct SendResponse: Decodable {
    let hash: String?
    let ok: Bool?
}
