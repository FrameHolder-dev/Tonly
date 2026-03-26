import SwiftUI

struct AddWalletSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Add Wallet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(TonlyTheme.textPrimary)

                    Text("Create a new wallet\nor add an existing one")
                        .font(.subheadline)
                        .foregroundStyle(TonlyTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                VStack(spacing: 10) {
                    addOption(
                        icon: "plus.circle.fill",
                        color: TonlyTheme.accent,
                        title: "New Wallet",
                        subtitle: "Create a new wallet"
                    ) {
                        showCreate = true
                    }

                    addOption(
                        icon: "arrow.right.circle.fill",
                        color: TonlyTheme.accent,
                        title: "Existing Wallet",
                        subtitle: "Import with 12 or 24 word seed phrase"
                    ) {
                        showImport = true
                    }
                }
                .padding(.horizontal, TonlyTheme.padding)

                Spacer()
            }
            .background(TonlyTheme.background)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TonlyTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(TonlyTheme.surface)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showCreate) {
            CreateWalletFlow(skipPIN: PINManager.isConfigured) { dismiss() }
        }
        .sheet(isPresented: $showImport) {
            ImportWalletView { dismiss() }
        }
    }

    private func addOption(icon: String, color: Color = TonlyTheme.accent, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(TonlyTheme.accent)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TonlyTheme.textPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
            .padding(16)
            .background(TonlyTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}
