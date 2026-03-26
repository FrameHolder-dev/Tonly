import Foundation

struct TONAddressValidator {
    enum AddressForm {
        case raw
        case bounceable
        case nonBounceable
        case domain
        case invalid
    }

    static func validate(_ input: String) -> AddressForm {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasSuffix(".ton") || trimmed.hasSuffix(".t.me") {
            return .domain
        }

        if trimmed.contains(":") && trimmed.count == 66 {
            return .raw
        }

        if trimmed.count == 48 {
            if trimmed.hasPrefix("EQ") {
                return .bounceable
            }
            if trimmed.hasPrefix("UQ") {
                return .nonBounceable
            }
        }

        return .invalid
    }

    static func isValid(_ input: String) -> Bool {
        validate(input) != .invalid
    }

    static func shouldBounce(_ input: String) -> Bool {
        validate(input) == .bounceable
    }
}
