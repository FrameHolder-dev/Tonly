import Foundation

extension Double {
    var tonFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "0.00"
    }

    var usdFormatted: String {
        currencyFormatted()
    }

    func currencyFormatted(_ code: String? = nil) -> String {
        let currency = code ?? UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "0.00"
    }

    static func fromNanoTON(_ nano: String) -> Double {
        guard let value = Double(nano) else { return 0 }
        return value / 1_000_000_000
    }
}
