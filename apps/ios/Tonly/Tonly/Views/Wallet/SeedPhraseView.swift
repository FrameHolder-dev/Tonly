import SwiftUI

struct SeedPhraseView: View {
    let words: [String]
    let onContinue: () -> Void
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Recovery Phrase")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text("Write down these words in order\nand keep them in a safe place")
                    .font(.subheadline)
                    .foregroundStyle(TonlyTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 24)

            if revealed {
                ScrollView {
                    wordGrid
                        .padding(.horizontal, TonlyTheme.padding)
                        .padding(.bottom, 100)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(TonlyTheme.textSecondary)

                    Text("Tap to reveal your recovery phrase")
                        .font(.body)
                        .foregroundStyle(TonlyTheme.textSecondary)
                }
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.4)) {
                        revealed = true
                    }
                    HapticService.impact()
                }
                Spacer()
            }

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(revealed ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
            }
            .disabled(!revealed)
            .padding(.horizontal, TonlyTheme.padding)
            .padding(.bottom, 32)
        }
        .background(TonlyTheme.background)
    }

    private var wordGrid: some View {
        let half = words.count / 2
        let left = Array(words.prefix(half))
        let right = Array(words.suffix(words.count - half))

        return HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(left.enumerated()), id: \.offset) { i, word in
                    wordRow(number: i + 1, word: word)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(right.enumerated()), id: \.offset) { i, word in
                    wordRow(number: half + i + 1, word: word)
                }
            }
        }
    }

    private func wordRow(number: Int, word: String) -> some View {
        HStack(spacing: 8) {
            Text("\(number).")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TonlyTheme.textSecondary)
                .frame(width: 30, alignment: .trailing)

            Text(word)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(TonlyTheme.textPrimary)
        }
    }
}
