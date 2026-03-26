import Foundation

extension String {
    var shortAddress: String {
        guard count > 10 else { return self }
        return "\(prefix(6))...\(suffix(4))"
    }

    var isValidTONAddress: Bool {
        count == 48 && (hasPrefix("EQ") || hasPrefix("UQ") || hasPrefix("0:") || hasPrefix("-1:"))
    }
}
