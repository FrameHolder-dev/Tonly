import SwiftUI

struct ImportWalletView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wordCount: WordCount = .twelve
    @State private var words: [String] = Array(repeating: "", count: 12)
    @FocusState private var focusedIndex: Int?

    enum WordCount: Int, CaseIterable {
        case twelve = 12
        case twentyFour = 24

        var label: String {
            "\(rawValue) Words"
        }
    }

    var isValid: Bool {
        words.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Word Count", selection: $wordCount) {
                    ForEach(WordCount.allCases, id: \.self) { count in
                        Text(count.label).tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .onChange(of: wordCount) { _, newValue in
                    words = Array(repeating: "", count: newValue.rawValue)
                    focusedIndex = 0
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(0..<words.count, id: \.self) { index in
                            WordField(
                                index: index + 1,
                                text: $words[index],
                                isFocused: focusedIndex == index,
                                onTap: { focusedIndex = index },
                                onSubmit: {
                                    if index < words.count - 1 {
                                        focusedIndex = index + 1
                                    } else {
                                        focusedIndex = nil
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, TonlyTheme.padding)
                    .padding(.bottom, 100)
                }

                VStack(spacing: 12) {
                    Button {
                        if let text = UIPasteboard.general.string {
                            let pasted = text
                                .components(separatedBy: CharacterSet.whitespacesAndNewlines)
                                .filter { !$0.isEmpty }
                            if pasted.count == 12 || pasted.count == 24 {
                                wordCount = pasted.count == 24 ? .twentyFour : .twelve
                                words = pasted
                                focusedIndex = nil
                                HapticService.notification(.success)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste from Clipboard")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TonlyTheme.accent)
                    }

                    Button {
                        guard isValid else { return }
                        let cleanWords = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                        do {
                            let walletData = try TONWalletManager.importWallet(seedPhrase: cleanWords)
                            WalletStore.shared.setWallet(from: walletData)
                            HapticService.notification(.success)
                            onComplete()
                        } catch {
                            HapticService.notification(.error)
                        }
                    } label: {
                        Text("Import")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? TonlyTheme.accent : TonlyTheme.surfaceLight)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    }
                    .disabled(!isValid)
                }
                .padding(TonlyTheme.padding)
                .background(TonlyTheme.background)
            }
            .background(TonlyTheme.background)
            .navigationTitle("Import Wallet")
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
        .onAppear {
            focusedIndex = 0
        }
    }
}

struct WordField: View {
    let index: Int
    @Binding var text: String
    let isFocused: Bool
    let onTap: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(TonlyTheme.textSecondary)
                .frame(width: 24)

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TonlyTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(onSubmit)
                .onTapGesture(perform: onTap)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(isFocused ? TonlyTheme.surfaceLight : TonlyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: TonlyTheme.cornerRadiusSmall)
                .stroke(isFocused ? TonlyTheme.accent : Color.clear, lineWidth: 1)
        )
    }
}
