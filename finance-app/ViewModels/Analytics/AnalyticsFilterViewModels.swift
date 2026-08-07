import Foundation

@MainActor
final class AnalyticsDirectionFilterViewModel {
    private let directions: [Direction?] = [nil, .outcome, .income]
    private let onSelect: (Direction?) -> Void
    private(set) var selectedDirection: Direction?

    init(selectedDirection: Direction?, onSelect: @escaping (Direction?) -> Void) {
        self.selectedDirection = selectedDirection
        self.onSelect = onSelect
    }

    var numberOfRows: Int {
        directions.count
    }

    func title(at index: Int) -> String {
        switch directions[index] {
        case nil:
            return "Все".appLocalized
        case .outcome:
            return "Расходы".appLocalized
        case .income:
            return "Доходы".appLocalized
        }
    }

    func isSelected(at index: Int) -> Bool {
        selectedDirection == directions[index]
    }

    func select(at index: Int) {
        selectedDirection = directions[index]
        onSelect(selectedDirection)
    }
}

@MainActor
final class AnalyticsSortOrderFilterViewModel {
    private let sortOrders: [SortOrder] = [.date, .amount]
    private let onSelect: (SortOrder) -> Void
    private(set) var selectedSortOrder: SortOrder

    init(selectedSortOrder: SortOrder, onSelect: @escaping (SortOrder) -> Void) {
        self.selectedSortOrder = selectedSortOrder
        self.onSelect = onSelect
    }

    var numberOfRows: Int {
        sortOrders.count
    }

    func title(at index: Int) -> String {
        sortOrders[index] == .date ? "По дате".appLocalized : "По сумме".appLocalized
    }

    func isSelected(at index: Int) -> Bool {
        selectedSortOrder == sortOrders[index]
    }

    func select(at index: Int) {
        selectedSortOrder = sortOrders[index]
        onSelect(selectedSortOrder)
    }
}

@MainActor
final class AnalyticsPeriodFilterViewModel {
    private enum Preset: Int, CaseIterable, Equatable {
        case custom
        case week
        case month
        case quarter
        case year
    }

    private let onSelect: (Date, Date, Bool) -> Void
    private let calendar: Calendar
    private let now: () -> Date
    private var selectedPreset: Preset
    private(set) var customStartDate: Date
    private(set) var customEndDate: Date

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppSettings.currentLanguage.locale
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    init(
        startDate: Date,
        endDate: Date,
        customStartDate: Date,
        customEndDate: Date,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        onSelect: @escaping (Date, Date, Bool) -> Void
    ) {
        self.onSelect = onSelect
        self.calendar = calendar
        self.now = now
        let today = calendar.startOfDay(for: now())
        self.customStartDate = min(calendar.startOfDay(for: customStartDate), today)
        self.customEndDate = min(calendar.startOfDay(for: customEndDate), today)
        if self.customStartDate > self.customEndDate {
            self.customStartDate = self.customEndDate
        }
        selectedPreset = Self.matchingPreset(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar,
            today: today
        )
    }

    var numberOfRows: Int {
        Preset.allCases.count
    }

    var customRowIndex: Int {
        Preset.custom.rawValue
    }

    var selectedRowIndex: Int {
        selectedPreset.rawValue
    }

    var formattedCustomPeriod: String {
        "\(dateFormatter.string(from: customStartDate)) – \(dateFormatter.string(from: customEndDate))"
    }

    func title(at index: Int) -> String {
        switch Preset.allCases[index] {
        case .custom:
            return "Произвольный".appLocalized
        case .week:
            return "За неделю".appLocalized
        case .month:
            return "За месяц".appLocalized
        case .quarter:
            return "За квартал".appLocalized
        case .year:
            return "За год".appLocalized
        }
    }

    func isSelected(at index: Int) -> Bool {
        selectedPreset == Preset.allCases[index]
    }

    func select(at index: Int) {
        let preset = Preset.allCases[index]
        if preset == .custom {
            applyCustomPeriod()
            return
        }
        guard let period = period(for: preset) else { return }
        selectedPreset = preset
        onSelect(period.start, period.end, false)
    }

    func startDateChanged(to date: Date) {
        customStartDate = clampedToToday(date)
        if customStartDate > customEndDate {
            customEndDate = customStartDate
        }
        applyCustomPeriod()
    }

    func endDateChanged(to date: Date) {
        customEndDate = clampedToToday(date)
        if customEndDate < customStartDate {
            customStartDate = customEndDate
        }
        applyCustomPeriod()
    }

    private func applyCustomPeriod() {
        selectedPreset = .custom
        onSelect(customStartDate, customEndDate, true)
    }

    private func clampedToToday(_ date: Date) -> Date {
        min(calendar.startOfDay(for: date), calendar.startOfDay(for: now()))
    }

    private func period(for preset: Preset) -> (start: Date, end: Date)? {
        Self.period(
            for: preset,
            calendar: calendar,
            today: calendar.startOfDay(for: now())
        )
    }

    private static func matchingPreset(
        startDate: Date,
        endDate: Date,
        calendar: Calendar,
        today: Date
    ) -> Preset {
        for preset in [Preset.week, .month, .quarter, .year] {
            guard let period = period(for: preset, calendar: calendar, today: today) else { continue }
            if calendar.isDate(startDate, inSameDayAs: period.start),
               calendar.isDate(endDate, inSameDayAs: period.end) {
                return preset
            }
        }
        return .custom
    }

    private static func period(
        for preset: Preset,
        calendar: Calendar,
        today: Date
    ) -> (start: Date, end: Date)? {
        let component: Calendar.Component
        let value: Int
        switch preset {
        case .custom:
            return nil
        case .week:
            component = .weekOfYear
            value = -1
        case .month:
            component = .month
            value = -1
        case .quarter:
            component = .month
            value = -3
        case .year:
            component = .year
            value = -1
        }
        guard let startDate = calendar.date(byAdding: component, value: value, to: today) else {
            return nil
        }
        return (calendar.startOfDay(for: startDate), today)
    }
}

struct AnalyticsCategoryRowViewData {
    let title: String
    let isSelected: Bool
}

@MainActor
final class AnalyticsCategoriesFilterViewModel {
    private let categories: [Category]
    private let onSave: (Set<Int>?) -> Void
    private var selectedCategoryIDs: Set<Int>

    init(
        categories: [Category],
        selectedCategoryIDs: Set<Int>?,
        onSave: @escaping (Set<Int>?) -> Void
    ) {
        self.categories = categories
        self.selectedCategoryIDs = selectedCategoryIDs ?? Set(categories.map(\.id))
        self.onSave = onSave
    }

    var numberOfRows: Int {
        categories.count
    }

    func row(at index: Int) -> AnalyticsCategoryRowViewData {
        let category = categories[index]
        return AnalyticsCategoryRowViewData(
            title: "\(category.emoji)  \(category.localizedName)",
            isSelected: selectedCategoryIDs.contains(category.id)
        )
    }

    func toggle(at index: Int) {
        let categoryID = categories[index].id
        if selectedCategoryIDs.contains(categoryID) {
            selectedCategoryIDs.remove(categoryID)
        } else {
            selectedCategoryIDs.insert(categoryID)
        }
    }

    func save() {
        let allCategoryIDs = Set(categories.map(\.id))
        onSave(selectedCategoryIDs == allCategoryIDs ? nil : selectedCategoryIDs)
    }
}

struct AnalyticsAccountRowViewData {
    let title: String
    let isSelected: Bool
}

@MainActor
final class AnalyticsAccountsFilterViewModel {
    private let accounts: [BankAccount]
    private let onSelect: (Int?) -> Void
    private(set) var selectedAccountID: Int?

    init(
        accounts: [BankAccount],
        selectedAccountID: Int?,
        onSelect: @escaping (Int?) -> Void
    ) {
        self.accounts = accounts
        self.selectedAccountID = selectedAccountID
        self.onSelect = onSelect
    }

    var numberOfRows: Int {
        accounts.count + 1
    }

    func row(at index: Int) -> AnalyticsAccountRowViewData {
        guard index > 0 else {
            return AnalyticsAccountRowViewData(
                title: "Все счета".appLocalized,
                isSelected: selectedAccountID == nil
            )
        }
        let account = accounts[index - 1]
        return AnalyticsAccountRowViewData(
            title: "\(account.emoji)  \(account.name)",
            isSelected: selectedAccountID == account.id
        )
    }

    func select(at index: Int) {
        selectedAccountID = index == 0 ? nil : accounts[index - 1].id
        onSelect(selectedAccountID)
    }
}
