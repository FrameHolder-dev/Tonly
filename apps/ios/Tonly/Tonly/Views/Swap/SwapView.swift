import SwiftUI
import TonSwift
import BigInt

struct SwapAsset: Codable, Identifiable {
    let address: String
    let symbol: String
    let name: String
    let imageURL: String
    let decimals: Int
    let verified: Bool

    var id: String { address }

    enum CodingKeys: String, CodingKey {
        case address, symbol, name, decimals, verified
        case imageURL = "image_url"
    }

    var iconURL: URL? { URL(string: imageURL) }

    static let tonAddress = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    static let usdtAddress = "EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"
}

struct SwapAssetsResponse: Codable {
    let assets: [SwapAsset]
}

struct SwapSimulateResponse: Codable {
    let offerAddress: String
    let askAddress: String
    let routerAddress: String
    let poolAddress: String
    let offerJettonWallet: String
    let askJettonWallet: String
    let offerUnits: String
    let askUnits: String
    let swapRate: String
    let minAskUnits: String
    let priceImpact: String
    let feeUnits: String
    let feePercent: String

    enum CodingKeys: String, CodingKey {
        case offerAddress = "offer_address"
        case askAddress = "ask_address"
        case routerAddress = "router_address"
        case poolAddress = "pool_address"
        case offerJettonWallet = "offer_jetton_wallet"
        case askJettonWallet = "ask_jetton_wallet"
        case offerUnits = "offer_units"
        case askUnits = "ask_units"
        case swapRate = "swap_rate"
        case minAskUnits = "min_ask_units"
        case priceImpact = "price_impact"
        case feeUnits = "fee_units"
        case feePercent = "fee_percent"
    }
}

struct SwapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var assets: [SwapAsset] = []
    @State private var fromAsset: SwapAsset?
    @State private var toAsset: SwapAsset?
    @State private var fromAmount = ""
    @State private var simulation: SwapSimulateResponse?
    @State private var isSimulating = false
    @State private var isSwapping = false
    @State private var showFromPicker = false
    @State private var showToPicker = false
    @State private var error: String?
    @State private var simulateTask: Task<Void, Never>?

    var fromAmountValue: Double { Double(fromAmount.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var isSameToken: Bool { fromAsset?.address == toAsset?.address }
    var tonBalance: Double { WalletStore.shared.balance }
    var exceedsBalance: Bool {
        guard fromAsset?.address == SwapAsset.tonAddress else { return false }
        return fromAmountValue > tonBalance
    }
    var canSwap: Bool { !fromAmount.isEmpty && fromAmountValue > 0 && !isSameToken && !exceedsBalance && simulation != nil }

    var estimatedReceive: String {
        guard let sim = simulation, let toDecimals = toAsset?.decimals else { return "0" }
        let ask = Double(sim.askUnits) ?? 0
        let value = ask / pow(10, Double(toDecimals))
        return String(format: "%.\(min(toDecimals, 6))f", value)
    }

    var buttonTitle: String {
        if fromAmount.isEmpty { return "Enter amount" }
        if isSameToken { return "Select different tokens" }
        if exceedsBalance { return "Insufficient balance" }
        if isSimulating { return "Calculating..." }
        if simulation == nil && fromAmountValue > 0 { return "Enter amount" }
        return "Swap"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                swapCard(
                    label: "You send",
                    asset: fromAsset,
                    amount: fromAmount,
                    editable: true,
                    showBalance: fromAsset?.address == SwapAsset.tonAddress
                ) { showFromPicker = true }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let tmp = fromAsset
                        fromAsset = toAsset
                        toAsset = tmp
                        fromAmount = ""
                        simulation = nil
                    }
                    HapticService.impact(.light)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TonlyTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(TonlyTheme.surface)
                        .clipShape(Circle())
                }

                swapCard(
                    label: "You receive",
                    asset: toAsset,
                    amount: estimatedReceive,
                    editable: false,
                    showBalance: false
                ) { showToPicker = true }

                if let sim = simulation, !isSimulating {
                    VStack(spacing: 8) {
                        infoRow("Rate", value: "1 \(fromAsset?.symbol ?? "") ≈ \(formatRate(sim.swapRate)) \(toAsset?.symbol ?? "")")
                        infoRow("Min receive", value: formatMinReceive(sim.minAskUnits))
                        infoRow("Price impact", value: sim.priceImpact + "%")
                        infoRow("Fee", value: "\(sim.feePercent)%")
                        infoRow("Route", value: "STON.fi")
                    }
                    .padding(14)
                    .background(TonlyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))
                }

                if isSimulating {
                    ProgressView()
                        .tint(TonlyTheme.accent)
                        .padding(8)
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.destructive)
                }

                Spacer()

                Button {
                    dismissKeyboard()
                    performSwap()
                } label: {
                    Group {
                        if isSwapping {
                            ProgressView().tint(.white)
                        } else {
                            Text(buttonTitle)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSwap ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                }
                .disabled(!canSwap || isSwapping)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, TonlyTheme.padding)
            .background(TonlyTheme.background)
            .navigationTitle("Swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismissKeyboard()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
            .onTapGesture { dismissKeyboard() }
            .onChange(of: fromAmount) { _, _ in debounceSimulate() }
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .task { await loadAssets() }
        .sheet(isPresented: $showFromPicker) {
            assetPicker { selected in
                if selected.address == toAsset?.address { toAsset = fromAsset }
                fromAsset = selected
                fromAmount = ""
                simulation = nil
            }
        }
        .sheet(isPresented: $showToPicker) {
            assetPicker { selected in
                if selected.address == fromAsset?.address { fromAsset = toAsset }
                toAsset = selected
                simulation = nil
                debounceSimulate()
            }
        }
    }

    private func swapCard(label: String, asset: SwapAsset?, amount: String, editable: Bool, showBalance: Bool, onSelect: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(TonlyTheme.textSecondary)

            HStack {
                if editable {
                    TextField("0", text: $fromAmount)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .foregroundStyle(TonlyTheme.textPrimary)
                } else {
                    Text(amount)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(TonlyTheme.textPrimary)
                }

                Spacer()

                Button(action: onSelect) {
                    HStack(spacing: 6) {
                        if let url = asset?.iconURL {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFit()
                            } placeholder: {
                                Circle().fill(TonlyTheme.surfaceLight)
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                        }

                        Text(asset?.symbol ?? "Select")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(TonlyTheme.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TonlyTheme.surfaceLight)
                    .clipShape(Capsule())
                }
            }

            if showBalance {
                Text("Balance: \(String(format: "%.4f", tonBalance)) TON")
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
        }
        .padding(16)
        .background(TonlyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
    }

    private func assetPicker(onSelect: @escaping (SwapAsset) -> Void) -> some View {
        NavigationStack {
            List(assets) { asset in
                Button {
                    onSelect(asset)
                    showFromPicker = false
                    showToPicker = false
                    HapticService.selection()
                } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: asset.iconURL) { img in
                            img.resizable().scaledToFit()
                        } placeholder: {
                            Circle().fill(TonlyTheme.surfaceLight)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.symbol)
                                .font(.body.weight(.medium))
                                .foregroundStyle(TonlyTheme.textPrimary)
                            Text(asset.name)
                                .font(.caption)
                                .foregroundStyle(TonlyTheme.textSecondary)
                        }

                        Spacer()

                        if asset.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(TonlyTheme.accent)
                        }
                    }
                }
                .listRowBackground(TonlyTheme.surface)
            }
            .listStyle(.plain)
            .background(TonlyTheme.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("Select Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    private func loadAssets() async {
        do {
            let response: SwapAssetsResponse = try await APIClient.shared.request(.swapAssets)
            assets = response.assets
            fromAsset = assets.first(where: { $0.address == SwapAsset.tonAddress })
            toAsset = assets.first(where: { $0.address == SwapAsset.usdtAddress })
        } catch {
            self.error = "Failed to load tokens"
        }
    }

    private func debounceSimulate() {
        simulateTask?.cancel()
        simulateTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            await simulate()
        }
    }

    private func simulate() async {
        guard let from = fromAsset, let to = toAsset else { return }
        guard fromAmountValue > 0 else {
            simulation = nil
            return
        }

        let units = String(Int(fromAmountValue * pow(10, Double(from.decimals))))

        isSimulating = true
        error = nil

        do {
            let response: SwapSimulateResponse = try await APIClient.shared.request(
                .swapSimulate(offerAddress: from.address, askAddress: to.address, units: units)
            )
            simulation = response
        } catch {
            simulation = nil
            self.error = "Failed to get swap quote"
        }

        isSimulating = false
    }

    private func performSwap() {
        guard let sim = simulation, let from = fromAsset, let to = toAsset else { return }

        isSwapping = true
        error = nil
        HapticService.impact()

        Task {
            let auth = await BiometricService.authenticate(reason: "Confirm swap")
            guard auth else {
                isSwapping = false
                error = "Authentication failed"
                return
            }

            do {
                let store = WalletStore.shared
                let seqnoResponse: SeqnoResponse = try await APIClient.shared.request(
                    .walletSeqno(address: store.apiAddress ?? "")
                )

                let keyPair = try TONWalletManager.getKeyPair()
                let walletId = WalletId(networkGlobalId: -239, workchain: 0, subwalletNumber: 0)
                let wallet = WalletV5R1(
                    seqno: Int64(seqnoResponse.seqno),
                    workchain: 0,
                    publicKey: keyPair.publicKey.data,
                    walletId: walletId
                )

                let userAddress = try wallet.address()
                let minAsk = BigUInt(sim.minAskUnits) ?? BigUInt(0)
                let askJettonWallet = try Address.parse(sim.askJettonWallet)

                let swapMsg: MessageRelaxed

                let offerAmount = BigUInt(sim.offerUnits) ?? BigUInt(0)
                let offerWallet = try Address.parse(sim.offerJettonWallet)

                if from.address == SwapAsset.tonAddress {
                    swapMsg = try StonfiSwapMessage.internalMessage(
                        userWalletAddress: userAddress,
                        minAskAmount: minAsk,
                        offerAmount: offerAmount,
                        jettonFromWalletAddress: offerWallet,
                        jettonToWalletAddress: askJettonWallet,
                        forwardAmount: STONFI_CONSTANTS.SWAP_TON_TO_JETTON.ForwardGasAmount,
                        attachedAmount: offerAmount + STONFI_CONSTANTS.SWAP_TON_TO_JETTON.ForwardGasAmount
                    )
                } else {
                    swapMsg = try StonfiSwapMessage.internalMessage(
                        userWalletAddress: userAddress,
                        minAskAmount: minAsk,
                        offerAmount: offerAmount,
                        jettonFromWalletAddress: offerWallet,
                        jettonToWalletAddress: askJettonWallet,
                        forwardAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_JETTON.ForwardGasAmount,
                        attachedAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_JETTON.GasAmount
                    )
                }

                let transferData = WalletTransferData(
                    seqno: UInt64(seqnoResponse.seqno),
                    messages: [swapMsg],
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
                isSwapping = false
                fromAmount = ""
                simulation = nil
                dismiss()
            } catch {
                self.error = "Swap failed: \(error.localizedDescription)"
                isSwapping = false
                HapticService.notification(.error)
            }
        }
    }

    private func formatRate(_ rate: String) -> String {
        guard let value = Double(rate) else { return rate }
        return String(format: "%.4f", value)
    }

    private func formatMinReceive(_ units: String) -> String {
        guard let value = Double(units), let toDecimals = toAsset?.decimals else { return units }
        let amount = value / pow(10, Double(toDecimals))
        return String(format: "%.\(min(toDecimals, 4))f \(toAsset?.symbol ?? "")", amount)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(TonlyTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(TonlyTheme.textPrimary)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
