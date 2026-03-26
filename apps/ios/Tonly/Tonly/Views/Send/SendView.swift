import SwiftUI

struct SendView: View {
    var prefillAddress: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var amount = ""
    @State private var comment = ""
    @State private var isSending = false
    @State private var error: String?
    @State private var showScanner = false
    @State private var showSuccess = false
    private let store = WalletStore.shared

    var amountValue: Double { Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var isSelfSend: Bool {
        guard let my = store.activeAddress else { return false }
        return address.trimmingCharacters(in: .whitespaces) == my
    }
    var exceedsBalance: Bool { amountValue > store.balance }
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
                            address = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TonlyTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TonlyTheme.surfaceLight)
                    .clipShape(Capsule())

                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20))
                            .foregroundStyle(TonlyTheme.accent)
                    }
                }
                .padding(14)
                .background(TonlyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))

                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundStyle(TonlyTheme.textSecondary)

                            TextField("0", text: $amount)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .foregroundStyle(TonlyTheme.textPrimary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            AsyncImage(url: Token.ton.iconURL) { img in
                                img.resizable().scaledToFit()
                            } placeholder: {
                                Circle().fill(TonlyTheme.accent)
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())

                            Text("TON")
                                .font(.headline)
                                .foregroundStyle(TonlyTheme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(TonlyTheme.surfaceLight)
                        .clipShape(Capsule())
                    }
                    .padding(14)
                    .background(TonlyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))

                    HStack {
                        let usd = amountValue * store.tonPrice
                        Text("\(usd.usdFormatted)")
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)

                        Spacer()

                        Text("Available \(store.balance.tonFormatted) TON")
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)

                        Button("MAX") {
                            let maxAmount = max(store.balance - 0.065, 0)
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
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView { scanned in
                address = scanned
                showScanner = false
            }
        }
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
            let seqnoResponse: SeqnoResponse = try await APIClient.shared.request(
                .walletSeqno(address: store.apiAddress ?? "")
            )

            let nanoAmount = TONTransactionBuilder.tonToNano(amountValue)
            let boc = try TONTransactionBuilder.buildTransfer(
                to: address,
                amount: nanoAmount,
                message: comment.isEmpty ? nil : comment,
                seqno: Int64(seqnoResponse.seqno)
            )

            let _: SendResponse = try await APIClient.shared.request(
                Endpoint(path: "/send", method: .post, body: ["boc": boc])
            )

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
}

struct SeqnoResponse: Decodable {
    let seqno: Int
}

struct SendResponse: Decodable {
    let hash: String?
    let ok: Bool?
}
