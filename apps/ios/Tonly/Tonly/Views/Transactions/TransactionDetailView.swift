import SwiftUI

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Circle()
                        .fill(transaction.isIncoming ? TonlyTheme.success.opacity(0.15) : TonlyTheme.accent.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: transaction.isIncoming ? "arrow.down.left" : "arrow.up.right")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(transaction.isIncoming ? TonlyTheme.success : TonlyTheme.accent)
                        }
                        .padding(.top, 16)

                    Text(transaction.formattedAmount)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(transaction.isIncoming ? TonlyTheme.success : TonlyTheme.textPrimary)

                    Text(transaction.status == .confirmed ? "Completed" : "Pending")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(transaction.status == .confirmed ? TonlyTheme.success : TonlyTheme.warning)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            (transaction.status == .confirmed ? TonlyTheme.success : TonlyTheme.warning).opacity(0.15)
                        )
                        .clipShape(Capsule())

                    VStack(spacing: 0) {
                        detailRow("From", value: transaction.from.shortAddress, full: transaction.from)
                        Divider().background(TonlyTheme.surfaceLight)
                        detailRow("To", value: transaction.to.shortAddress, full: transaction.to)
                        Divider().background(TonlyTheme.surfaceLight)
                        detailRow("Fee", value: "\(transaction.fee.tonFormatted) TON")
                        Divider().background(TonlyTheme.surfaceLight)
                        detailRow("Date", value: transaction.timestamp.formatted(date: .abbreviated, time: .shortened))

                        if let message = transaction.message, !message.isEmpty {
                            Divider().background(TonlyTheme.surfaceLight)
                            detailRow("Message", value: message)
                        }
                    }
                    .background(TonlyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    .padding(.horizontal, TonlyTheme.padding)

                    HStack(spacing: 16) {
                        Button {
                            UIPasteboard.general.string = transaction.hash
                            copied = true
                            HapticService.notification(.success)
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied" : "Copy Hash")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TonlyTheme.accent)
                        }

                        Button {
                            if let url = URL(string: "https://tonscan.org/tx/\(transaction.hash)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "safari")
                                Text("View on Tonscan")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TonlyTheme.accent)
                        }
                    }
                }
            }
            .background(TonlyTheme.background)
            .navigationTitle(transaction.isIncoming ? "Received" : "Sent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TonlyTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func detailRow(_ label: String, value: String, full: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(TonlyTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TonlyTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, TonlyTheme.padding)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if let full {
                UIPasteboard.general.string = full
                HapticService.selection()
            }
        }
    }
}
