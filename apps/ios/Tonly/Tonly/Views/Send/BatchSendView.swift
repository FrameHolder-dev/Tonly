import SwiftUI

struct BatchSendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipients: [BatchRecipient] = [BatchRecipient()]
    @State private var isSending = false

    struct BatchRecipient: Identifiable {
        let id = UUID()
        var address = ""
        var amount = ""
    }

    var totalAmount: Double {
        recipients.compactMap { Double($0.amount) }.reduce(0, +)
    }

    var isValid: Bool {
        recipients.allSatisfy { !$0.address.isEmpty && (Double($0.amount) ?? 0) > 0 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("W5 Multi-Send")
                                    .font(.headline)
                                    .foregroundStyle(TonlyTheme.textPrimary)

                                Text("Send to up to 255 addresses in one transaction")
                                    .font(.caption)
                                    .foregroundStyle(TonlyTheme.textSecondary)
                            }

                            Spacer()

                            Text("W5")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TonlyTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(TonlyTheme.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, TonlyTheme.padding)
                        .padding(.top, 16)

                        ForEach(Array(recipients.enumerated()), id: \.element.id) { index, _ in
                            recipientCard(index: index)
                        }

                        Button {
                            recipients.append(BatchRecipient())
                            HapticService.impact(.light)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Recipient")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TonlyTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TonlyTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))
                        }
                        .padding(.horizontal, TonlyTheme.padding)

                        if recipients.count > 1 {
                            HStack {
                                Text("Total")
                                    .font(.subheadline)
                                    .foregroundStyle(TonlyTheme.textSecondary)
                                Spacer()
                                Text("\(String(format: "%.4f", totalAmount)) TON")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(TonlyTheme.textPrimary)

                                Text("(\(recipients.count) recipients)")
                                    .font(.caption)
                                    .foregroundStyle(TonlyTheme.textSecondary)
                            }
                            .padding(.horizontal, TonlyTheme.padding)
                        }
                    }
                    .padding(.bottom, 100)
                }

                VStack(spacing: 8) {
                    if recipients.count > 1 {
                        Text("Fee: ~\(String(format: "%.3f", Double(recipients.count) * 0.003)) TON (batch)")
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }

                    Button {
                        Task { await send() }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Text(recipients.count > 1 ? "Send to \(recipients.count) recipients" : "Send TON")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValid ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    }
                    .disabled(!isValid || isSending)
                }
                .padding(TonlyTheme.padding)
                .background(TonlyTheme.background)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Multi-Send")
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

    private func recipientCard(index: Int) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("#\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TonlyTheme.textSecondary)
                Spacer()
                if recipients.count > 1 {
                    Button {
                        recipients.remove(at: index)
                        HapticService.impact(.light)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }

            TextField("TON address", text: $recipients[index].address)
                .font(.system(size: 14))
                .padding(12)
                .background(TonlyTheme.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(TonlyTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                TextField("0.00", text: $recipients[index].amount)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text("TON")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
            .padding(12)
            .background(TonlyTheme.surfaceLight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(TonlyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
        .padding(.horizontal, TonlyTheme.padding)
    }

    private func send() async {
        let authenticated = await BiometricService.authenticate(reason: "Confirm batch transaction")
        guard authenticated else { return }
        isSending = true
        try? await Task.sleep(for: .seconds(1.5))
        HapticService.transactionSent()
        isSending = false
        dismiss()
    }
}
