import SwiftUI

struct TransferConfirmationDetails {
    let title: String
    let amount: String
    let recipient: String
    let comment: String?
    let fee: Double?
    let iconURL: URL?
    let iconSymbol: String
    let action: String
}

struct TransferConfirmationView: View {
    let details: TransferConfirmationDetails
    let onConfirm: () async -> Void
    let onCancel: () -> Void

    @State private var isConfirming = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                    .padding(.top, 16)

                VStack(spacing: 0) {
                    infoRow(label: "Recipient", value: details.recipient.shortAddress)
                    Divider().background(TonlyTheme.surfaceLight).padding(.leading, 16)
                    infoRow(label: "Amount", value: details.amount)
                    if let comment = details.comment, !comment.isEmpty {
                        Divider().background(TonlyTheme.surfaceLight).padding(.leading, 16)
                        infoRow(label: "Comment", value: comment, valueMono: true)
                    }
                    Divider().background(TonlyTheme.surfaceLight).padding(.leading, 16)
                    infoRow(
                        label: "Fee",
                        value: details.fee.map { "~\(String(format: "%.4f", $0).trimmingTrailingZeros()) TON" } ?? "Calculating…"
                    )
                }
                .background(TonlyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                .padding(.horizontal, TonlyTheme.padding)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.destructive)
                        .padding(.horizontal, TonlyTheme.padding)
                }

                Spacer()

                Button {
                    Task { await confirm() }
                } label: {
                    Group {
                        if isConfirming {
                            ProgressView().tint(.white)
                        } else {
                            Text(details.action)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(TonlyTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                }
                .disabled(isConfirming)
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.bottom, 20)
            }
            .background(TonlyTheme.background)
            .navigationTitle(details.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Group {
                if let url = details.iconURL {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        Circle().fill(TonlyTheme.accent.opacity(0.15))
                    }
                } else {
                    Circle()
                        .fill(TonlyTheme.accent.opacity(0.15))
                        .overlay {
                            Text(String(details.iconSymbol.prefix(1)))
                                .font(.title.weight(.bold))
                                .foregroundStyle(TonlyTheme.accent)
                        }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            Text(details.amount)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(TonlyTheme.textPrimary)
        }
    }

    private func infoRow(label: String, value: String, valueMono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(TonlyTheme.textSecondary)
            Spacer()
            Text(value)
                .font(valueMono ? .subheadline.monospaced() : .subheadline.weight(.medium))
                .foregroundStyle(TonlyTheme.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func confirm() async {
        let auth = await BiometricService.authenticate(reason: details.title)
        guard auth else {
            error = "Authentication failed"
            return
        }
        isConfirming = true
        error = nil
        await onConfirm()
        isConfirming = false
    }
}
