import SwiftUI

struct StakeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var selectedPool: StakePool?

    struct StakePool: Identifiable {
        let id = UUID()
        let name: String
        let apy: String
        let minStake: String
        let icon: String
    }

    private let pools: [StakePool] = [
        StakePool(name: "TON Whales", apy: "3.8%", minStake: "50 TON", icon: "whale"),
        StakePool(name: "Bemo stTON", apy: "4.1%", minStake: "1 TON", icon: "drop.fill"),
        StakePool(name: "TON Nominators", apy: "3.5%", minStake: "10,001 TON", icon: "building.columns.fill"),
        StakePool(name: "Hipo hTON", apy: "4.0%", minStake: "1 TON", icon: "h.circle.fill"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Earn rewards by staking your TON")
                            .font(.subheadline)
                            .foregroundStyle(TonlyTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Staking Pools")
                            .font(.headline)
                            .foregroundStyle(TonlyTheme.textPrimary)
                            .padding(.horizontal, TonlyTheme.padding)

                        ForEach(pools) { pool in
                            Button {
                                selectedPool = pool
                                HapticService.selection()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: pool.icon)
                                        .font(.title3)
                                        .foregroundStyle(TonlyTheme.accent)
                                        .frame(width: 44, height: 44)
                                        .background(TonlyTheme.accent.opacity(0.15))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pool.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(TonlyTheme.textPrimary)

                                        Text("Min: \(pool.minStake)")
                                            .font(.caption)
                                            .foregroundStyle(TonlyTheme.textSecondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(pool.apy)
                                            .font(.body.weight(.bold))
                                            .foregroundStyle(TonlyTheme.success)

                                        Text("APY")
                                            .font(.caption)
                                            .foregroundStyle(TonlyTheme.textSecondary)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(TonlyTheme.textSecondary)
                                }
                                .padding(16)
                                .background(selectedPool?.id == pool.id ? TonlyTheme.surfaceLight : TonlyTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, TonlyTheme.padding)
                        }
                    }

                    if selectedPool != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount to stake")
                                .font(.caption)
                                .foregroundStyle(TonlyTheme.textSecondary)

                            HStack {
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(TonlyTheme.textPrimary)

                                Text("TON")
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(TonlyTheme.textSecondary)
                            }
                            .padding(14)
                            .background(TonlyTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))
                        }
                        .padding(.horizontal, TonlyTheme.padding)

                        Button {
                            HapticService.impact()
                        } label: {
                            let amtVal = Double(amount) ?? 0
                            let exceeds = amtVal > WalletStore.shared.balance
                            let valid = amtVal > 0 && !exceeds && selectedPool != nil
                            Text(exceeds ? "Insufficient balance" : (valid ? "Continue" : "Enter amount"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(valid ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                        }
                        .disabled((Double(amount) ?? 0) <= 0 || (Double(amount) ?? 0) > WalletStore.shared.balance || selectedPool == nil)
                        .padding(.horizontal, TonlyTheme.padding)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Stake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TonlyTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
