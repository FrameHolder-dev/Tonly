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

struct OmnistonParams: Codable {
    let swap: OmnistonSwap?
}

struct OmnistonSwap: Codable {
    let minAskAmount: String?
    let recommendedMinAskAmount: String?
    let recommendedSlippageBps: Int?

    enum CodingKeys: String, CodingKey {
        case minAskAmount = "min_ask_amount"
        case recommendedMinAskAmount = "recommended_min_ask_amount"
        case recommendedSlippageBps = "recommended_slippage_bps"
    }
}

struct OmnistonQuote: Codable {
    let quoteId: String
    let resolverName: String?
    let bidUnits: String
    let askUnits: String
    let referrerFeeUnits: String?
    let gasBudget: String?
    let params: OmnistonParams?

    enum CodingKeys: String, CodingKey {
        case quoteId = "quote_id"
        case resolverName = "resolver_name"
        case bidUnits = "bid_units"
        case askUnits = "ask_units"
        case referrerFeeUnits = "referrer_fee_units"
        case gasBudget = "gas_budget"
        case params
    }
}

struct OmnistonBuildResponse: Codable {
    let ton: OmnistonTONTx?
}

struct OmnistonTONTx: Codable {
    let messages: [OmnistonMessage]
}

struct OmnistonMessage: Codable {
    let targetAddress: String
    let sendAmount: String
    let payload: String?
    let jettonWalletStateInit: String?

    enum CodingKeys: String, CodingKey {
        case targetAddress = "target_address"
        case sendAmount = "send_amount"
        case payload
        case jettonWalletStateInit = "jetton_wallet_state_init"
    }
}

struct SwapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var assets: [SwapAsset] = []
    @State private var fromAsset: SwapAsset?
    @State private var toAsset: SwapAsset?
    @State private var fromAmount = ""
    @State private var simulation: OmnistonQuote?
    @State private var rawQuote: Data?
    @State private var isSimulating = false
    @State private var isSwapping = false
    @State private var showSwapConfirmation = false
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

    var swapRate: String {
        guard let sim = simulation,
              let from = fromAsset,
              let to = toAsset,
              let bidUnits = Double(sim.bidUnits),
              let askUnits = Double(sim.askUnits),
              bidUnits > 0 else { return "" }
        let bidValue = bidUnits / pow(10, Double(from.decimals))
        let askValue = askUnits / pow(10, Double(to.decimals))
        let rate = askValue / bidValue
        return String(format: "1 %@ ≈ %.4f %@", from.symbol, rate, to.symbol)
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
                        infoRow("Rate", value: swapRate)
                        if let minAsk = sim.params?.swap?.minAskAmount {
                            infoRow("Min receive", value: formatMinReceive(minAsk))
                        }
                        infoRow("Route", value: sim.resolverName ?? "Omniston")
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
                    showSwapConfirmation = true
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
        .sheet(isPresented: $showSwapConfirmation) {
            swapConfirmationSheet
        }
    }

    private var swapConfirmationSheet: some View {
        let fromSymbol = fromAsset?.symbol ?? ""
        let toSymbol = toAsset?.symbol ?? ""
        let bidAmount = "\(fromAmount.trimmingTrailingZeros()) \(fromSymbol)"
        let askAmount = "\(estimatedReceive) \(toSymbol)"
        let details = TransferConfirmationDetails(
            title: "Confirm Swap",
            amount: "\(bidAmount) → \(askAmount)",
            recipient: WalletStore.shared.activeAddress ?? "",
            comment: "via \(simulation?.resolverName ?? "Omniston")",
            fee: nil,
            iconURL: fromAsset?.iconURL,
            iconSymbol: fromSymbol,
            action: "Confirm Swap"
        )
        return TransferConfirmationView(
            details: details,
            onConfirm: {
                showSwapConfirmation = false
                performSwap()
            },
            onCancel: { showSwapConfirmation = false }
        )
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
                                Circle().fill(TonlyTheme.surface)
                            }
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                        }

                        Text(asset?.symbol ?? "Select")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TonlyTheme.textPrimary)
                            .lineLimit(1)

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
        VStack(spacing: 0) {
            Text("Select Token")
                .font(.headline)
                .foregroundStyle(TonlyTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
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
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(asset.symbol)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(TonlyTheme.textPrimary)
                                        if asset.verified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(TonlyTheme.accent)
                                        }
                                    }
                                    Text(asset.name)
                                        .font(.caption2)
                                        .foregroundStyle(TonlyTheme.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < assets.count - 1 {
                            Divider()
                                .background(TonlyTheme.surfaceLight)
                                .padding(.leading, 62)
                        }
                    }
                }
                .background(TonlyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.bottom, 16)
            }
        }
        .background(TonlyTheme.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
            rawQuote = nil
            return
        }

        let units = String(Int(fromAmountValue * pow(10, Double(from.decimals))))

        isSimulating = true
        error = nil

        do {
            let body: [String: Any] = [
                "bid_asset": from.address,
                "ask_asset": to.address,
                "bid_units": units,
                "slippage_bps": 100
            ]
            let url = URL(string: "https://api.tonly.one/api/v1/swap/quote")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 30

            let (data, _) = try await URLSession.shared.data(for: request)
            let quote = try JSONDecoder().decode(OmnistonQuote.self, from: data)
            simulation = quote
            rawQuote = data
        } catch {
            simulation = nil
            rawQuote = nil
            self.error = "Failed to get swap quote"
        }

        isSimulating = false
    }

    private func performSwap() {
        guard let sim = simulation, let rawData = rawQuote else { return }

        isSwapping = true
        error = nil
        HapticService.impact()

        Task {
            do {
                let store = WalletStore.shared
                guard let sourceAddr = store.activeAddress else {
                    throw NSError(domain: "swap", code: 1, userInfo: [NSLocalizedDescriptionKey: "No wallet"])
                }

                _ = sim
                let quoteJSON = try JSONSerialization.jsonObject(with: rawData)

                let buildBody: [String: Any] = [
                    "quote": quoteJSON,
                    "source_address": sourceAddr,
                    "destination_address": sourceAddr,
                    "gas_excess_address": sourceAddr
                ]
                let buildURL = URL(string: "https://api.tonly.one/api/v1/swap/build")!
                var buildReq = URLRequest(url: buildURL)
                buildReq.httpMethod = "POST"
                buildReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                buildReq.httpBody = try JSONSerialization.data(withJSONObject: buildBody)
                buildReq.timeoutInterval = 30

                let (buildData, _) = try await URLSession.shared.data(for: buildReq)
                let build = try JSONDecoder().decode(OmnistonBuildResponse.self, from: buildData)

                guard let messages = build.ton?.messages, !messages.isEmpty else {
                    throw NSError(domain: "swap", code: 2, userInfo: [NSLocalizedDescriptionKey: "No messages in transfer"])
                }

                var swapMessages: [MessageRelaxed] = []
                for message in messages {
                    let destAddress = try Address.parse(message.targetAddress)
                    let amountValue = BigUInt(message.sendAmount) ?? BigUInt(0)

                    let payloadCell: Cell
                    if let payloadHex = message.payload, !payloadHex.isEmpty,
                       let data = Data(hexString: payloadHex) {
                        let cells = try Cell.fromBoc(src: data)
                        payloadCell = cells.first ?? .empty
                    } else {
                        payloadCell = .empty
                    }

                    var stateInitCell: StateInit?
                    if let initHex = message.jettonWalletStateInit, !initHex.isEmpty,
                       let data = Data(hexString: initHex) {
                        let cells = try Cell.fromBoc(src: data)
                        if let root = cells.first {
                            stateInitCell = try root.beginParse().loadType() as StateInit
                        }
                    }

                    let msg = MessageRelaxed.internal(
                        to: destAddress,
                        value: amountValue,
                        bounce: true,
                        stateInit: stateInitCell,
                        body: payloadCell
                    )
                    swapMessages.append(msg)
                }

                try await TransferSigner.signAndBroadcast(messages: swapMessages)

                HapticService.transactionSent()
                isSwapping = false
                fromAmount = ""
                simulation = nil
                rawQuote = nil
                dismiss()
            } catch {
                self.error = "Swap failed: \(error.localizedDescription)"
                isSwapping = false
                HapticService.notification(.error)
            }
        }
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
