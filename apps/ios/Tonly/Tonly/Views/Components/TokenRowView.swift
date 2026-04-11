import SwiftUI

struct TokenRowView: View {
    let token: Token
    var priceChange: Double = 0
    @AppStorage("selectedCurrency") private var currency = "USD"

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: token.iconURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle()
                    .fill(TonlyTheme.surfaceLight)
                    .overlay {
                        Text(String(token.symbol.prefix(1)))
                            .font(.headline)
                            .foregroundStyle(TonlyTheme.accent)
                    }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(token.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(TonlyTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(token.usdPrice > 0 ? token.usdPrice.currencyFormatted(currency) : token.symbol)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.textSecondary)

                    if priceChange != 0 {
                        Text("\(priceChange > 0 ? "+" : "")\(String(format: "%.2f", priceChange))%")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(priceChange > 0 ? TonlyTheme.success : Color(hex: "FF3B30"))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(token.formattedBalance)
                    .font(.body.weight(.medium))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text(token.usdValue.currencyFormatted(currency))
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, TonlyTheme.padding)
    }
}
