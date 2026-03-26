import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(transaction.isIncoming ? TonlyTheme.success.opacity(0.15) : TonlyTheme.accent.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: transaction.isIncoming ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(transaction.isIncoming ? TonlyTheme.success : TonlyTheme.accent)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.isIncoming ? "Received" : "Sent")
                    .font(.body.weight(.medium))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text(transaction.isIncoming ? transaction.from.shortAddress : transaction.to.shortAddress)
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(.body.weight(.medium))
                    .foregroundStyle(transaction.isIncoming ? TonlyTheme.success : TonlyTheme.textPrimary)

                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, TonlyTheme.padding)
    }
}
