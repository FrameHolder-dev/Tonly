import UIKit

struct HapticService {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGen = UINotificationFeedbackGenerator()
    private static let selectionGen = UISelectionFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        switch style {
        case .light: lightImpact.impactOccurred()
        case .medium: mediumImpact.impactOccurred()
        case .heavy: heavyImpact.impactOccurred()
        default: mediumImpact.impactOccurred()
        }
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGen.notificationOccurred(type)
    }

    static func selection() {
        selectionGen.selectionChanged()
    }

    static func transactionSent() {
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            notificationGen.notificationOccurred(.success)
        }
    }

    static func transactionReceived() {
        notificationGen.notificationOccurred(.success)
    }
}
