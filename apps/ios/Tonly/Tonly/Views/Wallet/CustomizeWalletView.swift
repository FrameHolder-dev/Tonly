import SwiftUI

struct CustomizeWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var walletName = "Wallet"
    @State private var selectedColor: Color = .blue
    @State private var selectedEmoji = "creditcard.fill"

    let onSave: (String, String) -> Void

    private let colors: [Color] = [
        Color(hex: "8E8E93"), Color(hex: "3478F6"), Color(hex: "5856D6"),
        Color(hex: "FF2D55"), Color(hex: "FF9500"), Color(hex: "FFCC00"),
        Color(hex: "34C759"), Color(hex: "0098EA"), Color(hex: "AF52DE")
    ]

    private let icons = [
        "creditcard.fill", "leaf.fill", "lock.fill", "key.fill",
        "car.fill", "snowflake", "sparkles", "sun.max.fill",
        "hare.fill", "bolt.fill", "gearshape.fill", "hand.raised.fill",
        "magnifyingglass", "dollarsign.circle.fill", "eurosign.circle.fill",
        "sterlingsign.circle.fill", "yensign.circle.fill", "rublesign.circle.fill"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Customize Wallet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(TonlyTheme.textPrimary)

                    Text("Name and icon are stored\nlocally on your device")
                        .font(.subheadline)
                        .foregroundStyle(TonlyTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wallet name")
                            .font(.caption)
                            .foregroundStyle(TonlyTheme.textSecondary)

                        TextField("Wallet", text: $walletName)
                            .font(.body)
                            .foregroundStyle(TonlyTheme.textPrimary)
                    }

                    Spacer()

                    Image(systemName: selectedEmoji)
                        .font(.title2)
                        .foregroundStyle(selectedColor)
                        .frame(width: 48, height: 48)
                        .background(selectedColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
                .background(TonlyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                .padding(.horizontal, TonlyTheme.padding)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if selectedColor == color {
                                        Circle()
                                            .stroke(.white, lineWidth: 2)
                                    }
                                }
                                .onTapGesture {
                                    selectedColor = color
                                    HapticService.selection()
                                }
                        }
                    }
                    .padding(.horizontal, TonlyTheme.padding)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 7), spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(selectedEmoji == icon ? selectedColor : TonlyTheme.textSecondary)
                            .frame(width: 40, height: 40)
                            .onTapGesture {
                                selectedEmoji = icon
                                HapticService.selection()
                            }
                    }
                }
                .padding(.horizontal, TonlyTheme.padding)

                Spacer()

                Button {
                    onSave(walletName, selectedEmoji)
                    HapticService.notification(.success)
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TonlyTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                }
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.bottom, 32)
            }
            .background(TonlyTheme.background)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
