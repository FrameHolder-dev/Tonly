import SwiftUI

struct BalanceCardView: View {
    let balance: Double
    let usdBalance: Double
    let address: String
    @State private var copied = false
    @AppStorage("selectedCurrency") private var currency = "USD"

    var body: some View {
        VStack(spacing: 8) {
            Text(usdBalance.currencyFormatted(currency))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(TonlyTheme.textPrimary)

            Button {
                UIPasteboard.general.string = address
                copied = true
                HapticService.notification(.success)
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                HStack(spacing: 6) {
                    Text(copied ? "Copied!" : address.shortAddress)
                        .font(.caption)
                        .foregroundStyle(copied ? TonlyTheme.accent : TonlyTheme.textSecondary)

                    Text("W5")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TonlyTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TonlyTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
