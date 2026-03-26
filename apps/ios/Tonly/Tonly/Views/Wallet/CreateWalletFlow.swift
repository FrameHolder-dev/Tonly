import SwiftUI
import TonSwift

struct CreateWalletFlow: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var needsPIN: Bool
    @State private var pinSet = false
    @State private var generating = false
    @State private var seedWords: [String] = []
    @State private var walletAddress = ""
    @State private var showSeedIntro = false
    @State private var showSeedDisplay = false
    @State private var failed = false

    init(skipPIN: Bool = false, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        self._needsPIN = State(initialValue: !skipPIN && !PINManager.isConfigured)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TonlyTheme.background.ignoresSafeArea()

                if needsPIN && !pinSet {
                    SetPINView {
                        pinSet = true
                        needsPIN = false
                        startGeneration()
                    }
                } else if showSeedDisplay {
                    SeedPhraseView(words: seedWords) {
                        onComplete()
                    }
                } else if showSeedIntro {
                    seedIntroView
                } else {
                    loadingView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if needsPIN && !pinSet {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(TonlyTheme.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if showSeedIntro || showSeedDisplay {
                        Button("Skip") { onComplete() }
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarBackButtonHidden()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !needsPIN {
                startGeneration()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            if failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(TonlyTheme.destructive)

                Text("Failed to create wallet")
                    .font(.headline)
                    .foregroundStyle(TonlyTheme.textPrimary)

                Button("Try Again") { startGeneration() }
                    .font(.headline)
                    .foregroundStyle(TonlyTheme.accent)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(TonlyTheme.accent)

                Text("Creating wallet...")
                    .font(.headline)
                    .foregroundStyle(TonlyTheme.textPrimary)
            }
        }
    }

    private var seedIntroView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(TonlyTheme.accent)

                Text("Back Up Your Wallet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text("Your recovery phrase is the only way\nto restore your wallet if you lose access")
                    .font(.subheadline)
                    .foregroundStyle(TonlyTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showSeedDisplay = true
                }
            } label: {
                Text("Continue")
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
    }

    private func startGeneration() {
        guard !generating else { return }
        generating = true
        failed = false

        Task {
            do {
                let words = await SecureMnemonicClient.generate()

                let walletData = try await Task.detached(priority: .userInitiated) {
                    try TONWalletManager.createWallet(seedPhrase: words)
                }.value

                await MainActor.run {
                    seedWords = words
                    walletAddress = walletData.address
                    WalletStore.shared.setWallet(from: walletData)
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSeedIntro = true
                    }
                }
            } catch {
                await MainActor.run {
                    generating = false
                    failed = true
                }
            }
        }
    }
}
