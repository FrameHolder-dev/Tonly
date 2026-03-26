import SwiftUI

struct SetPINView: View {
    let onComplete: () -> Void
    @State private var step: Step = .create
    @State private var firstPIN = ""

    enum Step {
        case create
        case confirm
    }

    var body: some View {
        PINCodeView(
            title: step == .create ? "Set Passcode" : "Confirm Passcode",
            subtitle: step == .create ? "You will use it to unlock your wallet" : "Enter the passcode again",
            onComplete: { code in
                handlePIN(code)
            }
        )
    }

    private func handlePIN(_ code: String) {
        switch step {
        case .create:
            firstPIN = code
            withAnimation(.easeInOut(duration: 0.3)) {
                step = .confirm
            }
        case .confirm:
            if code == firstPIN {
                PINManager.store(code)
                HapticService.notification(.success)
                onComplete()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = .create
                    firstPIN = ""
                }
                HapticService.notification(.error)
            }
        }
    }
}
