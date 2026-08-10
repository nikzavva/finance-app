import UIKit

class AnalyticsFilterTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .label
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            style: .plain,
            target: self,
            action: #selector(saveTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "AccentColor")
    }

    func saveSelection() {}

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        tableView.rowHeight
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        cell.selectionStyle = .none
    }

    func configureCloseOnlyNavigation() {
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .label
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        saveSelection()
        dismiss(animated: true)
    }
}

final class AnalyticsDirectionViewController: AnalyticsFilterTableViewController {
    private let viewModel: AnalyticsDirectionFilterViewModel

    init(viewModel: AnalyticsDirectionFilterViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Тип".appLocalized
        configureCloseOnlyNavigation()
        tableView.isScrollEnabled = false
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "AnalyticsDirectionCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: identifier)
        var content = UIListContentConfiguration.cell()
        content.text = viewModel.title(at: indexPath.row)
        cell.contentConfiguration = content
        cell.accessoryType = viewModel.isSelected(at: indexPath.row) ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.select(at: indexPath.row)
        tableView.reloadData()
    }
}

final class AnalyticsSortOrderViewController: AnalyticsFilterTableViewController {
    private let viewModel: AnalyticsSortOrderFilterViewModel

    init(viewModel: AnalyticsSortOrderFilterViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Сортировка".appLocalized
        configureCloseOnlyNavigation()
        tableView.isScrollEnabled = false
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "AnalyticsSortOrderCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: identifier)
        var content = UIListContentConfiguration.cell()
        content.text = viewModel.title(at: indexPath.row)
        cell.contentConfiguration = content
        cell.accessoryType = viewModel.isSelected(at: indexPath.row) ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.select(at: indexPath.row)
        tableView.reloadData()
    }
}

final class AnalyticsPeriodViewController: AnalyticsFilterTableViewController {
    private let viewModel: AnalyticsPeriodFilterViewModel

    init(viewModel: AnalyticsPeriodFilterViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Период".appLocalized
        configureCloseOnlyNavigation()
        tableView.isScrollEnabled = false
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        indexPath.row == viewModel.customRowIndex
            ? customPeriodCell(tableView: tableView)
            : presetCell(at: indexPath.row, tableView: tableView)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.row == viewModel.customRowIndex
            ? UITableView.automaticDimension
            : super.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let previousSelectedRow = viewModel.selectedRowIndex
        viewModel.select(at: indexPath.row)
        if indexPath.row == viewModel.customRowIndex {
            updateCustomPeriodCell()
            reloadPreviousSelectionIfNeeded(previousSelectedRow)
        } else {
            tableView.reloadData()
        }
    }

    private func startDateChanged(to date: Date) {
        let previousSelectedRow = viewModel.selectedRowIndex
        viewModel.startDateChanged(to: date)
        updateCustomPeriodCell()
        reloadPreviousSelectionIfNeeded(previousSelectedRow)
    }

    private func endDateChanged(to date: Date) {
        let previousSelectedRow = viewModel.selectedRowIndex
        viewModel.endDateChanged(to: date)
        updateCustomPeriodCell()
        reloadPreviousSelectionIfNeeded(previousSelectedRow)
    }

    private func reloadPreviousSelectionIfNeeded(_ previousSelectedRow: Int) {
        guard previousSelectedRow != viewModel.customRowIndex else { return }
        tableView.reloadRows(
            at: [IndexPath(row: previousSelectedRow, section: 0)],
            with: .none
        )
    }

    private func customPeriodCell(tableView: UITableView) -> UITableViewCell {
        let identifier = "AnalyticsCustomPeriodCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? AnalyticsCustomPeriodCell
            ?? AnalyticsCustomPeriodCell(reuseIdentifier: identifier)
        configureCustomPeriodCell(cell)
        return cell
    }

    private func presetCell(at index: Int, tableView: UITableView) -> UITableViewCell {
        let identifier = "AnalyticsPeriodPresetCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: identifier)
        var content = UIListContentConfiguration.cell()
        content.text = viewModel.title(at: index)
        cell.contentConfiguration = content
        cell.accessoryType = viewModel.isSelected(at: index) ? .checkmark : .none
        return cell
    }

    private func updateCustomPeriodCell() {
        guard let cell = tableView.cellForRow(
            at: IndexPath(row: viewModel.customRowIndex, section: 0)
        ) as? AnalyticsCustomPeriodCell else {
            return
        }
        configureCustomPeriodCell(cell)
    }

    private func configureCustomPeriodCell(_ cell: AnalyticsCustomPeriodCell) {
        cell.configure(
            title: viewModel.title(at: viewModel.customRowIndex),
            period: viewModel.formattedCustomPeriod,
            startDate: viewModel.customStartDate,
            endDate: viewModel.customEndDate,
            isSelected: viewModel.isSelected(at: viewModel.customRowIndex),
            onStartDateChanged: { [weak self] date in
                self?.startDateChanged(to: date)
            },
            onEndDateChanged: { [weak self] date in
                self?.endDateChanged(to: date)
            }
        )
    }
}

private final class AnalyticsCustomPeriodCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let periodLabel = UILabel()
    private let checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark"))
    private let startDatePicker = UIDatePicker()
    private let endDatePicker = UIDatePicker()
    private var onStartDateChanged: ((Date) -> Void)?
    private var onEndDateChanged: ((Date) -> Void)?

    init(reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        title: String,
        period: String,
        startDate: Date,
        endDate: Date,
        isSelected: Bool,
        onStartDateChanged: @escaping (Date) -> Void,
        onEndDateChanged: @escaping (Date) -> Void
    ) {
        titleLabel.text = title
        periodLabel.text = period
        startDatePicker.date = startDate
        endDatePicker.date = endDate
        checkmarkImageView.alpha = isSelected ? 1 : 0
        self.onStartDateChanged = onStartDateChanged
        self.onEndDateChanged = onEndDateChanged
    }

    private func configureLayout() {
        selectionStyle = .none
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        periodLabel.font = .preferredFont(forTextStyle: .subheadline)
        periodLabel.textColor = .secondaryLabel
        periodLabel.adjustsFontForContentSizeCategory = true
        checkmarkImageView.tintColor = .systemBlue
        checkmarkImageView.setContentHuggingPriority(.required, for: .horizontal)

        configure(
            datePicker: startDatePicker,
            accessibilityLabel: "Начало периода".appLocalized,
            action: #selector(startDatePickerChanged)
        )
        configure(
            datePicker: endDatePicker,
            accessibilityLabel: "Конец периода".appLocalized,
            action: #selector(endDatePickerChanged)
        )

        let pickersStackView = UIStackView(arrangedSubviews: [
            startDatePicker,
            endDatePicker
        ])
        pickersStackView.axis = .vertical
        pickersStackView.alignment = .leading
        pickersStackView.spacing = UIStackView.spacingUseSystem

        let pickerSelectionStackView = UIStackView(arrangedSubviews: [
            pickersStackView,
            checkmarkImageView
        ])
        pickerSelectionStackView.axis = .horizontal
        pickerSelectionStackView.alignment = .center
        pickerSelectionStackView.spacing = UIStackView.spacingUseSystem

        let textStackView = UIStackView(arrangedSubviews: [
            titleLabel,
            periodLabel
        ])
        textStackView.axis = .vertical

        let spacer = UIView()
        let contentStackView = UIStackView(arrangedSubviews: [
            textStackView,
            spacer,
            pickerSelectionStackView
        ])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = UIStackView.spacingUseSystem
        contentView.addSubview(contentStackView)

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        periodLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pickerSelectionStackView.setContentHuggingPriority(.required, for: .horizontal)
        pickerSelectionStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        startDatePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        endDatePicker.setContentCompressionResistancePriority(.required, for: .horizontal)

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: margins.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            startDatePicker.widthAnchor.constraint(equalTo: endDatePicker.widthAnchor)
        ])
    }

    private func configure(
        datePicker: UIDatePicker,
        accessibilityLabel: String,
        action: Selector
    ) {
        datePicker.locale = AppSettings.currentLanguage.locale
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = Date()
        datePicker.accessibilityLabel = accessibilityLabel
        datePicker.addTarget(self, action: action, for: .valueChanged)
    }

    @objc private func startDatePickerChanged() {
        onStartDateChanged?(startDatePicker.date)
    }

    @objc private func endDatePickerChanged() {
        onEndDateChanged?(endDatePicker.date)
    }
}

final class AnalyticsCategoriesViewController: AnalyticsFilterTableViewController {
    private let viewModel: AnalyticsCategoriesFilterViewModel

    init(viewModel: AnalyticsCategoriesFilterViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Статьи".appLocalized
    }

    override func saveSelection() {
        viewModel.save()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.row(at: indexPath.row)
        let identifier = "AnalyticsCategoryCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: identifier)
        var content = UIListContentConfiguration.cell()
        content.text = row.title
        cell.contentConfiguration = content
        cell.accessoryType = row.isSelected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.toggle(at: indexPath.row)
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

final class AnalyticsAccountsViewController: AnalyticsFilterTableViewController {
    private let viewModel: AnalyticsAccountsFilterViewModel

    init(viewModel: AnalyticsAccountsFilterViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Счёт".appLocalized
        configureCloseOnlyNavigation()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.row(at: indexPath.row)
        let identifier = "AnalyticsAccountCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: identifier)
        var content = UIListContentConfiguration.cell()
        content.text = row.title
        cell.accessoryType = row.isSelected ? .checkmark : .none
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.select(at: indexPath.row)
        tableView.reloadData()
    }
}
