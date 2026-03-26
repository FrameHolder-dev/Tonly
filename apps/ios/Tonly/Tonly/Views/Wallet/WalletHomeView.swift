import SwiftUI

struct WalletHomeView: View {
    @State private var store = WalletStore.shared
    @State private var showSend = false
    @State private var showReceive = false
    @State private var showSwap = false
    @State private var showStake = false
    @State private var showToast = false
    @State private var selectedToken: Token?
    @State private var showAccountSwitcher = false
    @State private var showScan = false
    @State private var showBuy = false
    @State private var scannedAddress = ""
    @State private var selectedTransaction: Transaction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.isLoading && store.wallet?.balance == 0 {
                        SkeletonBalance()
                    } else {
                        BalanceCardView(
                            balance: store.balance,
                            usdBalance: store.wallet?.usdBalance ?? 0,
                            address: store.activeAddress ?? ""
                        )
                    }

                    ActionButtonsView(
                        onSend: { showSend = true },
                        onReceive: { showReceive = true },
                        onScan: { showScan = true },
                        onSwap: { showSwap = true },
                        onBuy: { showBuy = true },
                        onStake: { showStake = true }
                    )

                    tokenSection

                    recentSection
                }
            }
            .background(TonlyTheme.background)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showAccountSwitcher = true
                        HapticService.selection()
                    } label: {
                        HStack(spacing: 6) {
                            Text(store.wallet?.name ?? "Wallet")
                                .font(.headline)
                                .foregroundStyle(TonlyTheme.textPrimary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TonlyTheme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TonlyTheme.surface)
                        .clipShape(Capsule())
                    }
                }
            }
            .refreshable {
                await store.loadWallet()
                await store.loadTransactions()
            }
            .sheet(isPresented: $showSend, onDismiss: {
                scannedAddress = ""
                Task {
                    await store.loadWallet()
                    await store.loadTransactions()
                }
            }) {
                SendView(prefillAddress: scannedAddress)
            }
            .sheet(isPresented: $showReceive, onDismiss: {
                Task {
                    await store.loadWallet()
                    await store.loadTransactions()
                }
            }) {
                ReceiveView()
            }
            .toast(isPresented: $showToast, message: "Address copied")
            .fullScreenCover(item: $selectedToken) { token in
                TokenDetailView(token: token)
            }
            .sheet(isPresented: $showSwap) {
                SwapView()
            }
            .sheet(isPresented: $showStake) {
                StakeView()
            }
            .sheet(isPresented: $showAccountSwitcher) {
                AccountSwitcherView()
            }
            .fullScreenCover(isPresented: $showScan) {
                QRScannerView { address in
                    scannedAddress = address
                    showScan = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSend = true
                    }
                }
            }
            .sheet(isPresented: $showBuy) {
                WebBrowserView(url: URL(string: "https://widget.mercuryo.io/?currency=TON&type=buy")!)
            }
            .sheet(item: $selectedTransaction) { tx in
                TransactionDetailView(transaction: tx)
            }
            .task {
                if store.wallet == nil {
                    store.restoreWallet()
                }
                guard store.wallet != nil else { return }
                do {
                    await store.loadWallet()
                    await store.loadTransactions()
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(60))
                        await store.loadWallet()
                    }
                } catch {}
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var tokenSection: some View {
        Text("Tokens")
            .font(.headline)
            .foregroundStyle(TonlyTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TonlyTheme.padding)

        VStack(alignment: .leading, spacing: 0) {
            if store.isLoading && (store.wallet?.tokens.isEmpty ?? true) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRow()
                }
            } else {
                ForEach(store.wallet?.tokens ?? []) { token in
                    TokenRowView(
                        token: token,
                        priceChange: token.id == "ton" ? store.tonPriceChange24h : 0
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedToken = token
                        HapticService.selection()
                    }
                }
            }
        }
        .background(TonlyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
        .padding(.horizontal, TonlyTheme.padding)
    }

    @ViewBuilder
    private var recentSection: some View {
        if store.isLoading {
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundStyle(TonlyTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, TonlyTheme.padding)
                    .padding(.bottom, 8)

                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRow()
                }
            }
        } else if !store.transactions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundStyle(TonlyTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, TonlyTheme.padding)
                    .padding(.bottom, 8)

                ForEach(store.transactions.filter({ $0.amount >= 0.001 }).prefix(5)) { tx in
                    TransactionRowView(transaction: tx)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTransaction = tx
                            HapticService.selection()
                        }
                }
            }
        }
    }
}
