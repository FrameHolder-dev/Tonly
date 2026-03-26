import SwiftUI

enum TonlyTheme {
    static let accent = Color(hex: "0098EA")
    static let background = Color(hex: "0F0F0F")
    static let surface = Color(hex: "1A1A1A")
    static let surfaceLight = Color(hex: "2A2A2A")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
    static let success = Color(hex: "34C759")
    static let destructive = Color(hex: "FF3B30")
    static let warning = Color(hex: "FF9500")

    static let cornerRadius: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 12
    static let padding: CGFloat = 16
    static let paddingSmall: CGFloat = 8
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
