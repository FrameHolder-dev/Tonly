import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var showCreate = false
    @State private var showImport = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            TonlyTheme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(TonlyTheme.accent)

                    Text("Tonly")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(TonlyTheme.textPrimary)

                    HStack(spacing: 6) {
                        Text("The fastest TON wallet powered by")
                            .font(.body)
                            .foregroundStyle(TonlyTheme.textSecondary)

                        Text("W5")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(TonlyTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(TonlyTheme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showCreate = true
                    } label: {
                        Text("Create Wallet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(TonlyTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    }

                    Button {
                        showImport = true
                    } label: {
                        Text("Import Wallet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(TonlyTheme.surface)
                            .foregroundStyle(TonlyTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    }
                }
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appeared = true
            }
        }
        .fullScreenCover(isPresented: $showCreate) {
            CreateWalletFlow(onComplete: {
                showCreate = false
                onComplete()
            })
        }
        .sheet(isPresented: $showImport) {
            ImportWalletView(onComplete: {
                showImport = false
                onComplete()
            })
        }
    }
}
