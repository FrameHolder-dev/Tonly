import SwiftUI

struct LockScreenView: View {
    let onUnlock: () -> Void
    @State private var wrongAttempt = false

    var body: some View {
        ZStack {
            TonlyTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(TonlyTheme.accent)
                    .padding(.top, 60)

                PINCodeView(
                    title: "Enter Passcode",
                    subtitle: wrongAttempt ? "Wrong passcode" : nil,
                    onComplete: { code in
                        if PINManager.check(code) {
                            HapticService.notification(.success)
                            onUnlock()
                        } else {
                            wrongAttempt = true
                            HapticService.notification(.error)
                        }
                    }
                )
            }
        }
        .task {
            if BiometricService.availableType != .none {
                let success = await BiometricService.authenticate(reason: "Unlock Tonly")
                if success {
                    await MainActor.run { onUnlock() }
                }
            }
        }
    }
}
