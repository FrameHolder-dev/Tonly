import SwiftUI
import TonSwift

struct ConfirmSeedView: View {
    let words: [String]
    let onComplete: () -> Void
    @State private var checks: [SeedCheck] = []
    @State private var currentCheck = 0
    @State private var error = false
    @State private var ready = false

    struct SeedCheck: Identifiable {
        let id = UUID()
        let wordIndex: Int
        let correctWord: String
        let options: [String]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Verify Phrase")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text("Select the correct word for each position")
                    .font(.subheadline)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
            .padding(.top, 24)

            Spacer()

            if ready && currentCheck < checks.count {
                let check = checks[currentCheck]

                VStack(spacing: 32) {
                    Text("Word #\(check.wordIndex + 1)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(TonlyTheme.accent)

                    if error {
                        Text("Wrong word, try again")
                            .font(.subheadline)
                            .foregroundStyle(TonlyTheme.destructive)
                    }

                    VStack(spacing: 12) {
                        ForEach(check.options, id: \.self) { option in
                            Button {
                                handleAnswer(option)
                            } label: {
                                Text(option)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(TonlyTheme.surface)
                                    .foregroundStyle(TonlyTheme.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))
                            }
                        }
                    }
                    .padding(.horizontal, TonlyTheme.padding)
                }

                Text("\(currentCheck + 1) of \(checks.count)")
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
                    .padding(.top, 24)
            }

            Spacer()
        }
        .background(TonlyTheme.background)
        .task {
            generateChecks()
        }
    }

    private let fakeWords = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
        "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
        "across", "action", "actor", "actual", "adapt", "address", "adjust", "admit",
        "adult", "advance", "advice", "aerobic", "affair", "afford", "afraid", "again",
        "agent", "agree", "ahead", "alien", "almost", "alone", "alpha", "already",
        "alter", "always", "amazing", "among", "amount", "angry", "animal", "announce",
        "annual", "another", "answer", "anxiety", "apart", "apology", "appear", "apple",
        "arena", "army", "arrest", "arrive", "arrow", "artist", "artwork", "aspect"
    ]

    private func generateChecks() {
        let allWords: [String]
        let mnemonicWords = Mnemonic.words
        if mnemonicWords.count > 100 {
            allWords = mnemonicWords
        } else {
            allWords = fakeWords
        }

        guard words.count >= 3 else {
            ready = true
            return
        }

        var indices = Array(0..<words.count)
        indices.shuffle()
        let selected = Array(indices.prefix(3))

        var result: [SeedCheck] = []
        for index in selected {
            let correct = words[index]
            var options = [correct]
            var attempts = 0
            while options.count < 3 && attempts < 50 {
                let random = allWords[Int.random(in: 0..<allWords.count)]
                if !options.contains(random) {
                    options.append(random)
                }
                attempts += 1
            }
            options.shuffle()
            result.append(SeedCheck(wordIndex: index, correctWord: correct, options: options))
        }

        checks = result
        ready = true
    }

    private func handleAnswer(_ answer: String) {
        if answer == checks[currentCheck].correctWord {
            error = false
            HapticService.notification(.success)
            withAnimation(.easeInOut(duration: 0.3)) {
                currentCheck += 1
            }
            if currentCheck >= checks.count {
                onComplete()
            }
        } else {
            error = true
            HapticService.notification(.error)
        }
    }
}
