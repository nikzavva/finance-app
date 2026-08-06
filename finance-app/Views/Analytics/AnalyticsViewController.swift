import PieChart
import UIKit

final class AnalyticsViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case filters
        case transactions
    }

    private enum SheetSizing {
        case medium
        case resizable
    }

    private let viewModel: AnalyticsViewModel
    private let onBack: () -> Void
    private var sizedHeaderSize: CGSize?

    private let chartHeaderView = UIView()
    private let pieChartView = PieChartView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(viewModel: AnalyticsViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureChartHeader()
        configureTableView()
        configureActivityIndicator()
        bindViewModel()
        viewModel.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableHeaderSizeIfNeeded()
    }

    func stop() {
        viewModel.stop()
    }

    private func configureNavigation() {
        title = "Аналитика"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .label
    }

    private func configureChartHeader() {
        pieChartView.translatesAutoresizingMaskIntoConstraints = false
        pieChartView.currencySymbol = "₽"
        pieChartView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(chartTapped))
        )
        chartHeaderView.addSubview(pieChartView)

        NSLayoutConstraint.activate([
            pieChartView.topAnchor.constraint(equalTo: chartHeaderView.topAnchor),
            pieChartView.leadingAnchor.constraint(equalTo: chartHeaderView.leadingAnchor),
            pieChartView.trailingAnchor.constraint(equalTo: chartHeaderView.trailingAnchor),
            pieChartView.bottomAnchor.constraint(equalTo: chartHeaderView.bottomAnchor)
        ])
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.sectionHeaderTopPadding = .zero
        tableView.tableHeaderView = chartHeaderView
        tableView.register(
            AnalyticsTransactionCell.self,
            forCellReuseIdentifier: AnalyticsTransactionCell.reuseIdentifier
        )
        tableView.register(
            UITableViewHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: "AnalyticsTransactionsHeader"
        )
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.onChange = { [weak self] change in
            self?.render(change)
        }
    }

    private func render(_ change: AnalyticsViewModel.Change) {
        switch change {
        case .loading:
            if viewModel.isLoading {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        case .filters:
            tableView.reloadSections(IndexSet(integer: Section.filters.rawValue), with: .none)
        case .content:
            pieChartView.entities = viewModel.chartEntities
            sizedHeaderSize = nil
            updateTableHeaderSizeIfNeeded()
            tableView.reloadSections(IndexSet(integer: Section.transactions.rawValue), with: .none)
        }
    }

    private func updateTableHeaderSizeIfNeeded() {
        let width = tableView.bounds.width
        guard width > .zero else { return }
        chartHeaderView.bounds.size.width = width
        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let height = chartHeaderView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let size = CGSize(width: width, height: height)
        guard sizedHeaderSize != size else { return }
        sizedHeaderSize = size
        chartHeaderView.frame.size = size
        tableView.tableHeaderView = chartHeaderView
    }

    @objc private func backButtonTapped() {
        onBack()
    }

    @objc private func chartTapped() {
        let detailsViewModel = AnalyticsChartDetailsViewModel(
            entities: viewModel.chartEntities,
            currencySymbol: "₽"
        )
        let controller = AnalyticsChartDetailsViewController(viewModel: detailsViewModel)
        presentSheet(controller, sizing: .resizable)
    }

    private func presentDirectionPicker() {
        let controller = AnalyticsDirectionViewController(
            viewModel: viewModel.makeDirectionViewModel()
        )
        presentSheet(controller, sizing: .medium)
    }

    private func presentPeriodPicker() {
        let controller = AnalyticsPeriodViewController(
            viewModel: viewModel.makePeriodViewModel()
        )
        presentSheet(controller, sizing: .medium)
    }

    private func presentSortOrderPicker() {
        let controller = AnalyticsSortOrderViewController(
            viewModel: viewModel.makeSortOrderViewModel()
        )
        presentSheet(controller, sizing: .medium)
    }

    private func presentCategoriesPicker() {
        let controller = AnalyticsCategoriesViewController(
            viewModel: viewModel.makeCategoriesViewModel()
        )
        presentSheet(controller, sizing: .resizable)
    }

    private func presentAccountsPicker() {
        let controller = AnalyticsAccountsViewController(
            viewModel: viewModel.makeAccountsViewModel()
        )
        presentSheet(controller, sizing: .resizable)
    }

    private func presentSheet(_ rootViewController: UIViewController, sizing: SheetSizing) {
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.modalPresentationStyle = .pageSheet

        if let sheet = navigationController.sheetPresentationController {
            sheet.prefersGrabberVisible = false
            switch sizing {
            case .medium:
                sheet.detents = [.medium()]
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            case .resizable:
                sheet.prefersGrabberVisible = true
                sheet.detents = [.medium(), .large()]
            }
        }

        present(navigationController, animated: true) { [weak self, weak navigationController] in
            guard case .medium = sizing,
                  let self,
                  let containerView = navigationController?.presentationController?.containerView else {
                return
            }
            let tapGestureRecognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(self.sheetBackgroundTapped(_:))
            )
            tapGestureRecognizer.cancelsTouchesInView = false
            tapGestureRecognizer.delegate = self
            containerView.addGestureRecognizer(tapGestureRecognizer)
        }
    }

    @objc private func sheetBackgroundTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended,
              let presentedViewController else {
            return
        }
        presentedViewController.dismiss(animated: true)
    }
}

extension AnalyticsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchedView = touch.view,
              let presentedViewController else {
            return true
        }
        var visibleViewController: UIViewController? = presentedViewController
        while let currentViewController = visibleViewController {
            if touchedView.isDescendant(of: currentViewController.view) {
                return false
            }
            visibleViewController = currentViewController.presentedViewController
        }
        return true
    }
}

extension AnalyticsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .filters:
            return AnalyticsFilter.allCases.count
        case .transactions:
            return viewModel.transactionRows.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .filters:
            let identifier = "AnalyticsFilterCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
                ?? UITableViewCell(style: .value1, reuseIdentifier: identifier)
            guard let filter = AnalyticsFilter(rawValue: indexPath.row) else { return cell }
            let row = viewModel.filterRow(for: filter)
            var content = UIListContentConfiguration.valueCell()
            content.text = row.title
            content.secondaryText = row.value
            content.secondaryTextProperties.lineBreakMode = .byTruncatingTail
            cell.contentConfiguration = content
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
        case .transactions:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: AnalyticsTransactionCell.reuseIdentifier,
                for: indexPath
            ) as? AnalyticsTransactionCell ?? AnalyticsTransactionCell()
            cell.configure(with: viewModel.transactionRows[indexPath.row])
            return cell
        }
    }
}

extension AnalyticsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard Section(rawValue: section) == .transactions else {
            return .leastNormalMagnitude
        }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard Section(rawValue: section) == .filters else {
            return .leastNormalMagnitude
        }
        return UIFont.preferredFont(forTextStyle: .caption1).lineHeight
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        Section(rawValue: section) == .filters ? UIView() : nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .transactions else { return nil }
        let identifier = "AnalyticsTransactionsHeader"
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: identifier)
            ?? UITableViewHeaderFooterView(reuseIdentifier: identifier)
        var content = UIListContentConfiguration.header()
        content.text = "Транзакции"
        content.textProperties.color = .label
        let font = UIFont.preferredFont(forTextStyle: .title2)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
            content.textProperties.font = UIFont(descriptor: descriptor, size: font.pointSize)
        } else {
            content.textProperties.font = font
        }
        header.contentConfiguration = content
        return header
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == Section.filters.rawValue,
              let filter = AnalyticsFilter(rawValue: indexPath.row) else {
            return
        }

        switch filter {
        case .direction:
            presentDirectionPicker()
        case .period:
            presentPeriodPicker()
        case .sortOrder:
            presentSortOrderPicker()
        case .categories:
            presentCategoriesPicker()
        case .account:
            presentAccountsPicker()
        }
    }
}

private final class AnalyticsTransactionCell: UITableViewCell {
    static let reuseIdentifier = "AnalyticsTransactionCell"

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with row: AnalyticsTransactionRowViewData) {
        emojiLabel.text = row.emoji
        titleLabel.text = row.title
        amountLabel.text = row.amount
    }

    private func configureLayout() {
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = .preferredFont(forTextStyle: .title3)
        emojiLabel.textAlignment = .center
        emojiLabel.layer.cornerRadius = UIConstants.Sizes.icon / 2
        emojiLabel.layer.borderWidth = 1 / UIScreen.main.scale
        emojiLabel.layer.borderColor = UIColor.systemGray5.cgColor
        emojiLabel.clipsToBounds = true
        contentView.addSubview(emojiLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(titleLabel)

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = .preferredFont(forTextStyle: .body)
        amountLabel.textColor = .label
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(amountLabel)

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            emojiLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            emojiLabel.topAnchor.constraint(equalTo: margins.topAnchor),
            emojiLabel.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            emojiLabel.widthAnchor.constraint(equalToConstant: UIConstants.Sizes.icon),
            emojiLabel.heightAnchor.constraint(equalToConstant: UIConstants.Sizes.icon),
            titleLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: UIConstants.Spacing.small),
            titleLabel.centerYAnchor.constraint(equalTo: margins.centerYAnchor),
            amountLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor,
                constant: UIConstants.Spacing.small
            ),
            amountLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            amountLabel.centerYAnchor.constraint(equalTo: margins.centerYAnchor)
        ])
    }
}
