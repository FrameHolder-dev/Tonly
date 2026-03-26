import SwiftUI

struct SettingsView: View {
    @State private var store = WalletStore.shared
    @State private var showDeleteConfirm = false
    @State private var showCurrency = false
    @State private var showBackup = false
    @State private var seedWords: [String] = []
    @State private var showSeedPhrase = false
    @State private var webURL: URL?
    @State private var showWeb = false
    @AppStorage("selectedCurrency") private var currency = "USD"

    static let currencies: [(code: String, name: String, symbol: String)] = [
        ("USD", "US Dollar", "$"), ("EUR", "Euro", "€"), ("GBP", "British Pound", "£"),
        ("RUB", "Russian Ruble", "₽"), ("UAH", "Ukrainian Hryvnia", "₴"),
        ("KZT", "Kazakh Tenge", "₸"), ("BYN", "Belarusian Ruble", "Br"),
        ("CNY", "Chinese Yuan", "¥"), ("JPY", "Japanese Yen", "¥"),
        ("KRW", "Korean Won", "₩"), ("INR", "Indian Rupee", "₹"),
        ("TRY", "Turkish Lira", "₺"), ("BRL", "Brazilian Real", "R$"),
        ("AED", "UAE Dirham", "د.إ"), ("SGD", "Singapore Dollar", "S$"),
        ("HKD", "Hong Kong Dollar", "HK$"), ("CAD", "Canadian Dollar", "C$"),
        ("AUD", "Australian Dollar", "A$"), ("CHF", "Swiss Franc", "Fr"),
        ("PLN", "Polish Zloty", "zł"), ("THB", "Thai Baht", "฿"),
        ("IDR", "Indonesian Rupiah", "Rp"), ("PHP", "Philippine Peso", "₱"),
        ("NGN", "Nigerian Naira", "₦"), ("ZAR", "South African Rand", "R"),
        ("GEL", "Georgian Lari", "₾"), ("AMD", "Armenian Dram", "֏")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    settingsGroup {
                        settingsRow(
                            title: "Backup",
                            iconName: "key.fill",
                            iconBg: TonlyTheme.accent
                        ) { showBackup = true }

                        Divider().padding(.leading, 56)

                        settingsRow(
                            title: "Notifications",
                            iconName: "bell.badge.fill",
                            iconBg: TonlyTheme.accent
                        ) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }

                        Divider().padding(.leading, 56)

                        settingsRow(
                            title: "Currency",
                            iconName: "dollarsign",
                            iconBg: TonlyTheme.accent,
                            value: currency
                        ) { showCurrency = true }
                    }

                    settingsGroup {
                        settingsRow(
                            title: "Support",
                            iconName: "envelope.fill",
                            iconBg: TonlyTheme.accent
                        ) {
                            if let url = URL(string: "mailto:support@tonly.one") {
                                UIApplication.shared.open(url)
                            }
                        }

                        Divider().padding(.leading, 56)

                        settingsRow(
                            title: "Tonly News",
                            iconName: "paperplane.fill",
                            iconBg: TonlyTheme.accent
                        ) {
                            openURL("https://t.me/tonly_wallet")
                        }

                        Divider().padding(.leading, 56)

                        settingsRow(
                            title: "Rate Tonly",
                            iconName: "star.fill",
                            iconBg: TonlyTheme.accent
                        ) {}
                    }

                    settingsGroup {
                        settingsRow(
                            title: "Privacy Policy",
                            iconName: "hand.raised.fill",
                            iconBg: TonlyTheme.accent
                        ) {
                            openInApp("https://tonly.one/en/privacy")
                        }

                        Divider().padding(.leading, 56)

                        settingsRow(
                            title: "Terms of Service",
                            iconName: "doc.text.fill",
                            iconBg: TonlyTheme.accent
                        ) {
                            openInApp("https://tonly.one/en/terms")
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                        HapticService.impact()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                            Text("Delete Wallet")
                                .font(.body.weight(.medium))
                        }
                        .foregroundStyle(TonlyTheme.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TonlyTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.title2)
                            .foregroundStyle(TonlyTheme.accent)

                        Text("Tonly")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TonlyTheme.textSecondary)

                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary.opacity(0.6))
                    }
                    .padding(.vertical, 16)
                }
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.top, 8)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Delete Wallet?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        let auth = await BiometricService.authenticate(reason: "Confirm wallet deletion")
                        if auth {
                            TONWalletManager.deleteWallet()
                            if TONWalletManager.hasWallet() {
                                store.restoreWallet()
                                Task { await store.loadWallet() }
                            } else {
                                store.wallet = nil
                            }
                        }
                    }
                }
            } message: {
                Text("Make sure you have backed up your seed phrase. This cannot be undone.")
            }
            .sheet(isPresented: $showCurrency) {
                currencyPicker
            }
            .sheet(isPresented: $showBackup) {
                backupSheet
            }
            .sheet(isPresented: $showSeedPhrase) {
                seedPhraseSheet
            }
            .sheet(isPresented: $showWeb) {
                if let url = webURL {
                    WebBrowserView(url: url)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func settingsGroup(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(TonlyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
    }

    private func settingsRow(title: String, iconName: String, iconBg: Color, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(title)
                    .font(.body)
                    .foregroundStyle(TonlyTheme.textPrimary)

                Spacer()

                if let value {
                    Text(value)
                        .font(.body)
                        .foregroundStyle(TonlyTheme.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TonlyTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var currencyPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Self.currencies, id: \.code) { cur in
                        Button {
                            currency = cur.code
                            HapticService.selection()
                            showCurrency = false
                            Task { await store.loadWallet() }
                        } label: {
                            HStack(spacing: 14) {
                                Text(cur.symbol)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .frame(width: 34, height: 34)
                                    .background(TonlyTheme.surfaceLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(TonlyTheme.textPrimary)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cur.code)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(TonlyTheme.textPrimary)
                                    Text(cur.name)
                                        .font(.caption)
                                        .foregroundStyle(TonlyTheme.textSecondary)
                                }

                                Spacer()

                                if cur.code == currency {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(TonlyTheme.accent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
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
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showCurrency = false } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var backupSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(TonlyTheme.accent)

                Text("View Recovery Phrase")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text("Authenticate to view your seed phrase")
                    .font(.subheadline)
                    .foregroundStyle(TonlyTheme.textSecondary)

                Spacer()

                Button {
                    Task {
                        let auth = await BiometricService.authenticate(reason: "View recovery phrase")
                        if auth {
                            guard let activeId = TONWalletManager.getActiveWalletId() else { return }
                            let key = "\(activeId)_seed_phrase"
                            if let data = try? KeychainManager.read(key: key),
                               let phrase = String(data: data, encoding: .utf8) {
                                seedWords = phrase.components(separatedBy: " ")
                                showBackup = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    showSeedPhrase = true
                                }
                            }
                        }
                    }
                } label: {
                    Text("Authenticate")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TonlyTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                }
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.bottom, 32)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showBackup = false } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var seedPhraseSheet: some View {
        NavigationStack {
            ScrollView {
                SeedPhraseView(words: seedWords, onContinue: { showSeedPhrase = false })
                    .padding(.top, 20)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Recovery Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showSeedPhrase = false } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }

    private func openInApp(_ string: String) {
        if let url = URL(string: string) {
            webURL = url
            showWeb = true
        }
    }
}
