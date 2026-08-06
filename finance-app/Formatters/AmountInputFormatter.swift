import Foundation

enum AmountInputFormatter {
    static func parse(_ string: String) -> Decimal? {
        if string.isEmpty || string == "0" {
            return Decimal.zero
        }
        let separator = Locale.current.decimalSeparator ?? ","
        let cleaned = string
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: separator, with: ".")
        return Decimal(string: cleaned)
    }

    static func format(_ value: Decimal, with formatter: NumberFormatter) -> String {
        formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
}
