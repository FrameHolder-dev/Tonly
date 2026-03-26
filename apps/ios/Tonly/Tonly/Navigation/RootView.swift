import SwiftUI

struct RootView: View {
    @State private var store = WalletStore.shared
    @State private var appState: AppState = .loading
    @State private var splashOpacity: Double = 0
    @State private var splashScale: CGFloat = 0.8
    @State private var loadingDots = ""

    enum AppState {
        case loading
        case onboarding
        case locked
        case unlocked
    }

    var body: some View {
        Group {
            switch appState {
            case .loading:
                splashScreen
            case .onboarding:
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appState = .unlocked
                    }
                }
                .transition(.opacity)
            case .locked:
                LockScreenView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState = .unlocked
                    }
                }
                .transition(.opacity)
            case .unlocked:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState)
        .task {
            withAnimation(.easeOut(duration: 0.6)) {
                splashOpacity = 1
                splashScale = 1
            }

            await APIClient.shared.waitForAPI()

            TONWalletManager.migrateIfNeeded()
            let hasWallet = store.hasWallet()
            if hasWallet {
                store.restoreWallet()
                withAnimation(.easeInOut(duration: 0.4)) {
                    appState = PINManager.isConfigured ? .locked : .unlocked
                }
            } else {
                withAnimation(.easeInOut(duration: 0.4)) {
                    appState = .onboarding
                }
            }
        }
    }

    private var splashScreen: some View {
        ZStack {
            TonlyTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(TonlyTheme.accent)

                Text("Tonly")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(TonlyTheme.textPrimary)

                ProgressView()
                    .tint(TonlyTheme.textSecondary)
                    .padding(.top, 24)
            }
            .scaleEffect(splashScale)
            .opacity(splashOpacity)
        }
    }
}

extension RootView.AppState: Equatable {}
