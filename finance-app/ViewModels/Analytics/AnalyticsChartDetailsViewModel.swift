import Foundation
import PieChart
import UIKit

struct AnalyticsChartDetailsRowViewData {
    let title: String
    let details: String
    let progress: Float
    let color: UIColor
}

@MainActor
final class AnalyticsChartDetailsViewModel {
    let entities: [Entity]
    let currencySymbol: String
    private(set) var rows: [AnalyticsChartDetailsRowViewData] = []

    private let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    init(entities: [Entity], currencySymbol: String) {
        self.entities = entities
        self.currencySymbol = currencySymbol
        let segments = PieChartView.segments(from: entities)
        let total = segments.reduce(Decimal.zero) { $0 + $1.entity.value }
        rows = segments.map { segment in
            let ratio = total > .zero ? segment.entity.value / total : .zero
            let amount = amountFormatter.string(
                from: NSDecimalNumber(decimal: segment.entity.value)
            ) ?? "0"
            let percentage = percentFormatter.string(
                from: NSDecimalNumber(decimal: ratio)
            ) ?? "0%"
            return AnalyticsChartDetailsRowViewData(
                title: segment.entity.label,
                details: "\(amount) \(currencySymbol) · \(percentage)",
                progress: Float(NSDecimalNumber(decimal: ratio).doubleValue),
                color: segment.color
            )
        }
    }
}
