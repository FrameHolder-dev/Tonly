import SwiftUI

struct ActionButtonsView: View {
    let onSend: () -> Void
    let onReceive: () -> Void
    let onScan: () -> Void
    var onSwap: () -> Void = {}
    var onBuy: () -> Void = {}
    var onStake: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActionButton(title: "Send", icon: "arrow.up", action: onSend)
                ActionButton(title: "Receive", icon: "arrow.down", action: onReceive)
                ActionButton(title: "Scan", icon: "qrcode.viewfinder", action: onScan)
            }
            HStack(spacing: 12) {
                ActionButton(title: "Swap", icon: "arrow.triangle.swap", action: onSwap)
                ActionButton(title: "Buy", icon: "dollarsign", action: onBuy)
                ActionButton(title: "Stake", icon: "chart.line.uptrend.xyaxis", action: onStake)
            }
        }
        .padding(.horizontal, TonlyTheme.padding)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(TonlyTheme.accent.opacity(0.15))
                    .foregroundStyle(TonlyTheme.accent)
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
