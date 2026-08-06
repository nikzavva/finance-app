import UIKit
import PieChart

final class AnalyticsChartDetailsViewController: AnalyticsFilterTableViewController {
    private let viewModel: AnalyticsChartDetailsViewModel
    private var sizedHeaderSize: CGSize?

    private let chartHeaderView = UIView()
    private let pieChartView = PieChartView()

    init(viewModel: AnalyticsChartDetailsViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Детализация"
        configureCloseOnlyNavigation()
        configureChartHeader()
        configureTableView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableHeaderSizeIfNeeded()
    }

    private func configureChartHeader() {
        pieChartView.translatesAutoresizingMaskIntoConstraints = false
        pieChartView.currencySymbol = viewModel.currencySymbol
        pieChartView.showsLegend = false
        pieChartView.entities = viewModel.entities
        chartHeaderView.addSubview(pieChartView)

        NSLayoutConstraint.activate([
            pieChartView.topAnchor.constraint(equalTo: chartHeaderView.topAnchor),
            pieChartView.leadingAnchor.constraint(equalTo: chartHeaderView.leadingAnchor),
            pieChartView.trailingAnchor.constraint(equalTo: chartHeaderView.trailingAnchor),
            pieChartView.bottomAnchor.constraint(equalTo: chartHeaderView.bottomAnchor)
        ])
    }

    private func configureTableView() {
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.register(
            AnalyticsChartDetailsCell.self,
            forCellReuseIdentifier: AnalyticsChartDetailsCell.reuseIdentifier
        )
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
        let isInitialSize = sizedHeaderSize == nil
        sizedHeaderSize = size
        chartHeaderView.frame.size = size
        tableView.tableHeaderView = chartHeaderView
        if isInitialSize {
            tableView.setContentOffset(
                CGPoint(x: .zero, y: -tableView.adjustedContentInset.top),
                animated: false
            )
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: AnalyticsChartDetailsCell.reuseIdentifier,
            for: indexPath
        ) as? AnalyticsChartDetailsCell ?? AnalyticsChartDetailsCell()
        let row = viewModel.rows[indexPath.row]
        cell.configure(
            title: row.title,
            details: row.details,
            progress: row.progress,
            color: row.color
        )
        return cell
    }
}

private final class AnalyticsChartDetailsCell: UITableViewCell {
    static let reuseIdentifier = "AnalyticsChartDetailsCell"

    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String, details: String, progress: Float, color: UIColor) {
        titleLabel.text = title
        detailsLabel.text = details
        progressView.progress = min(max(progress, 0), 1)
        progressView.progressTintColor = color
    }

    private func configureLayout() {
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        detailsLabel.font = .preferredFont(forTextStyle: .body)
        detailsLabel.textColor = .label
        detailsLabel.textAlignment = .right
        detailsLabel.setContentHuggingPriority(.required, for: .horizontal)
        detailsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let headingStack = UIStackView(arrangedSubviews: [titleLabel, detailsLabel])
        headingStack.axis = .horizontal
        headingStack.alignment = .firstBaseline
        headingStack.spacing = UIStackView.spacingUseSystem

        let contentStack = UIStackView(arrangedSubviews: [headingStack, progressView])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = UIStackView.spacingUseSystem
        contentView.addSubview(contentStack)

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: margins.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: margins.bottomAnchor)
        ])
    }
}
