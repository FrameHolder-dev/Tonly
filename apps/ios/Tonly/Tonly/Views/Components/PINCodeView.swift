import SwiftUI

struct PINCodeView: View {
    let title: String
    let subtitle: String?
    let onComplete: (String) -> Void
    @State private var pin = ""
    @State private var shake = false
    private let pinLength = 4

    var body: some View {
        ZStack {
            TonlyTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(TonlyTheme.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }

                Spacer()
                    .frame(height: 40)

                HStack(spacing: 16) {
                    ForEach(0..<pinLength, id: \.self) { index in
                        Circle()
                            .fill(index < pin.count ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                            .frame(width: 16, height: 16)
                            .animation(.easeOut(duration: 0.1), value: pin.count)
                    }
                }
                .offset(x: shake ? -10 : 0)

                Spacer()

                numpad
                    .padding(.bottom, 40)
            }
        }
    }

    private var numpad: some View {
        VStack(spacing: 20) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 36) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        numpadButton(String(number))
                    }
                }
            }

            HStack(spacing: 36) {
                Color.clear.frame(width: 75, height: 75)

                numpadButton("0")

                Button {
                    guard !pin.isEmpty else { return }
                    pin.removeLast()
                } label: {
                    Image(systemName: "delete.backward.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(TonlyTheme.textPrimary)
                        .frame(width: 75, height: 75)
                }
            }
        }
    }

    private func numpadButton(_ digit: String) -> some View {
        Button {
            guard pin.count < pinLength else { return }
            pin.append(digit)
            HapticService.impact(.light)

            if pin.count == pinLength {
                let completed = pin
                DispatchQueue.main.async {
                    onComplete(completed)
                    pin = ""
                }
            }
        } label: {
            Text(digit)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(TonlyTheme.textPrimary)
                .frame(width: 75, height: 75)
        }
    }
}
