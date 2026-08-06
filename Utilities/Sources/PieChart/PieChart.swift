import UIKit

public struct Entity: Equatable {
    public let value: Decimal
    public let label: String

    public init(value: Decimal, label: String) {
        self.value = value
        self.label = label
    }
}

public struct PieChartSegment {
    public let entity: Entity
    public let color: UIColor

    public init(entity: Entity, color: UIColor) {
        self.entity = entity
        self.color = color
    }
}

public final class PieChartView: UIView {
    public var entities: [Entity] = [] {
        didSet {
            invalidateIntrinsicContentSize()
            scheduleTransition()
        }
    }

    public var currencySymbol: String? {
        didSet {
            setNeedsDisplay()
        }
    }

    public var showsLegend = true {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    private enum Animation {
        static let halfDuration: TimeInterval = 0.45
        static let key = "PieChartTransition"
    }

    private static let colors: [UIColor] = [
        .systemBlue,
        .systemGreen,
        .systemOrange,
        .systemPurple,
        .systemPink,
        .systemGray
    ]

    private let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    private var displayedEntities: [Entity] = []
    private var pendingEntities: [Entity]?
    private var hasReceivedEntities = false
    private var isAnimatingTransition = false
    private var isTransitionScheduled = false
    private var lastChartDiameter: CGFloat = .zero
    private var hidesDrawnContent = false
    private var contentOverlayView: UIImageView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public convenience init(entities: [Entity]) {
        self.init(frame: .zero)
        self.entities = entities
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public override var intrinsicContentSize: CGSize {
        let legendHeight = showsLegend ? 3 * legendRowHeight : .zero
        let spacing = showsLegend ? sectionSpacing : .zero
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: sectionSpacing
                + chartDiameter(for: resolvedWidth)
                + spacing
                + legendHeight
                + sectionSpacing
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let currentChartDiameter = chartDiameter(for: bounds.width)
        if lastChartDiameter != currentChartDiameter {
            lastChartDiameter = currentChartDiameter
            invalidateIntrinsicContentSize()
        }
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        guard !hidesDrawnContent else { return }
        drawContent(for: displayedEntities, in: rect, context: context)
    }

    public static func segments(from entities: [Entity]) -> [PieChartSegment] {
        var result = entities.prefix(5).enumerated().compactMap { index, entity -> PieChartSegment? in
            guard entity.value > .zero else { return nil }
            return PieChartSegment(entity: entity, color: colors[index])
        }

        if entities.count > 5 {
            let otherValue = entities.dropFirst(5).reduce(Decimal.zero) { partialResult, entity in
                partialResult + max(entity.value, .zero)
            }
            if otherValue > .zero {
                result.append(
                    PieChartSegment(
                        entity: Entity(value: otherValue, label: "Другое"),
                        color: colors[5]
                    )
                )
            }
        }
        return result
    }

    private static func legendSegments(from segments: [PieChartSegment]) -> [PieChartSegment] {
        guard segments.count > 2 else { return segments }
        let otherValue = segments.dropFirst(2).reduce(Decimal.zero) {
            $0 + $1.entity.value
        }
        return Array(segments.prefix(2)) + [
            PieChartSegment(
                entity: Entity(value: otherValue, label: "Другое"),
                color: segments[2].color
            )
        ]
    }

    private var legendRowHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    private var sectionSpacing: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption1).lineHeight
    }

    private var resolvedWidth: CGFloat {
        if bounds.width > .zero {
            return bounds.width
        }
        guard let superview else { return .zero }
        return superview.bounds.width
    }

    private func chartDiameter(for width: CGFloat) -> CGFloat {
        let availableWidth = max(width - layoutMargins.left - layoutMargins.right, .zero)
        let readableWidth = readableContentGuide.layoutFrame.width
        let contentWidth = readableWidth > .zero
            ? min(availableWidth, readableWidth)
            : availableWidth
        return contentWidth * 2 / 3
    }

    private func donutWidth(for diameter: CGFloat) -> CGFloat {
        min(
            UIFont.preferredFont(forTextStyle: .body).lineHeight,
            diameter / 2
        )
    }

    private func contentRect(in rect: CGRect) -> CGRect {
        rect.inset(
            by: UIEdgeInsets(
                top: sectionSpacing,
                left: layoutMargins.left,
                bottom: sectionSpacing,
                right: layoutMargins.right
            )
        )
    }

    private func chartRect(in rect: CGRect) -> CGRect {
        let contentRect = contentRect(in: rect)
        let diameter = chartDiameter(for: rect.width)
        return CGRect(
            x: contentRect.midX - diameter / 2,
            y: contentRect.minY,
            width: diameter,
            height: diameter
        )
    }

    private func configure() {
        backgroundColor = .clear
        contentMode = .redraw
        isOpaque = false
    }

    private func scheduleTransition() {
        guard !isTransitionScheduled else { return }
        isTransitionScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isTransitionScheduled = false
            processTransition(to: entities)
        }
    }

    private func processTransition(to newEntities: [Entity]) {
        if !hasReceivedEntities {
            hasReceivedEntities = true
            displayImmediately(newEntities)
            return
        }

        if isAnimatingTransition {
            pendingEntities = newEntities
            return
        }

        guard displayedEntities != newEntities else { return }
        guard window != nil else {
            displayImmediately(newEntities)
            return
        }
        animateTransition(to: newEntities)
    }

    private func displayImmediately(_ newEntities: [Entity]) {
        displayedEntities = newEntities
        pendingEntities = nil
        contentOverlayView?.layer.removeAnimation(forKey: Animation.key)
        contentOverlayView?.removeFromSuperview()
        contentOverlayView = nil
        hidesDrawnContent = false
        setNeedsDisplay()
    }

    private func animateTransition(to newEntities: [Entity]) {
        isAnimatingTransition = true
        layoutIfNeeded()
        let overlayView = makeContentOverlay(for: displayedEntities)
        contentOverlayView = overlayView
        hidesDrawnContent = true
        setNeedsDisplay()
        layer.displayIfNeeded()
        animate(
            layer: overlayView.layer,
            fromAngle: .zero,
            toAngle: .pi,
            fromOpacity: 1,
            toOpacity: 0,
            timingFunction: CAMediaTimingFunction(name: .easeIn)
        ) { [weak self] in
            guard let self else { return }
            displayedEntities = newEntities
            overlayView.image = contentImage(
                for: newEntities,
                size: overlayView.bounds.size
            )
            setNeedsDisplay()
            layer.displayIfNeeded()
            animate(
                layer: overlayView.layer,
                fromAngle: .pi,
                toAngle: .pi * 2,
                fromOpacity: 0,
                toOpacity: 1,
                timingFunction: CAMediaTimingFunction(name: .easeOut)
            ) { [weak self] in
                self?.completeTransition()
            }
        }
    }

    private func animate(
        layer animatedLayer: CALayer,
        fromAngle: CGFloat,
        toAngle: CGFloat,
        fromOpacity: Float,
        toOpacity: Float,
        timingFunction: CAMediaTimingFunction,
        completion: @escaping () -> Void
    ) {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = fromAngle
        rotation.toValue = toAngle

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = fromOpacity
        fade.toValue = toOpacity

        let animation = CAAnimationGroup()
        animation.animations = [rotation, fade]
        animation.duration = Animation.halfDuration
        animation.timingFunction = timingFunction

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animatedLayer.transform = CATransform3DMakeRotation(toAngle, 0, 0, 1)
        animatedLayer.opacity = toOpacity
        CATransaction.commit()

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        animatedLayer.add(animation, forKey: Animation.key)
        CATransaction.commit()
    }

    private func completeTransition() {
        contentOverlayView?.layer.removeAnimation(forKey: Animation.key)
        hidesDrawnContent = false
        setNeedsDisplay()
        layer.displayIfNeeded()
        contentOverlayView?.removeFromSuperview()
        contentOverlayView = nil
        isAnimatingTransition = false

        guard let pendingEntities else { return }
        self.pendingEntities = nil
        processTransition(to: pendingEntities)
    }

    private func makeContentOverlay(for entities: [Entity]) -> UIImageView {
        let size = bounds.size
        let imageView = UIImageView(
            image: contentImage(for: entities, size: size)
        )
        imageView.bounds = CGRect(origin: .zero, size: size)
        let chartFrame = chartRect(in: imageView.bounds)
        let chartCenter = CGPoint(x: chartFrame.midX, y: chartFrame.midY)
        imageView.layer.anchorPoint = CGPoint(
            x: size.width > .zero ? chartCenter.x / size.width : 0.5,
            y: size.height > .zero ? chartCenter.y / size.height : 0.5
        )
        imageView.layer.position = chartCenter
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
        return imageView
    }

    private func contentImage(for entities: [Entity], size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            let rect = CGRect(origin: .zero, size: size)
            drawContent(for: entities, in: rect, context: rendererContext.cgContext)
        }
    }

    private func drawContent(
        for entities: [Entity],
        in rect: CGRect,
        context: CGContext
    ) {
        let segments = Self.segments(from: entities)
        let total = segments.reduce(Decimal.zero) { $0 + $1.entity.value }
        let contentRect = contentRect(in: rect)
        let chartRect = chartRect(in: rect)

        drawDonut(
            in: chartRect,
            segments: segments,
            total: total,
            context: context
        )
        drawTotal(total, in: chartRect)

        let legendSegments = Self.legendSegments(from: segments)
        guard showsLegend, !legendSegments.isEmpty else { return }
        let legendOrigin = CGPoint(
            x: contentRect.minX,
            y: chartRect.maxY + sectionSpacing
        )
        drawLegend(
            segments: legendSegments,
            origin: legendOrigin,
            width: contentRect.width,
            context: context
        )
    }

    private func drawDonut(
        in rect: CGRect,
        segments: [PieChartSegment],
        total: Decimal,
        context: CGContext
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let lineWidth = donutWidth(for: rect.width)
        let radius = max((rect.width - lineWidth) / 2, .zero)

        guard total > .zero else {
            context.setStrokeColor(UIColor.tertiarySystemFill.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
            return
        }

        let totalValue = NSDecimalNumber(decimal: total).doubleValue
        var startAngle = -CGFloat.pi / 2

        for segment in segments {
            let value = NSDecimalNumber(decimal: segment.entity.value).doubleValue
            let angle = CGFloat(value / totalValue) * 2 * .pi
            let endAngle = startAngle + angle
            let path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            path.lineWidth = lineWidth
            path.lineCapStyle = .butt
            segment.color.setStroke()
            path.stroke()
            startAngle = endAngle
        }
    }

    private func drawTotal(_ total: Decimal, in chartRect: CGRect) {
        let amount = amountFormatter.string(from: NSDecimalNumber(decimal: total)) ?? "0"
        let amountText = currencySymbol.map { "\(amount) \($0)" } ?? amount
        let titleText = "Всего за период"
        let lineWidth = donutWidth(for: chartRect.width)
        let availableWidth = max(chartRect.width - lineWidth * 2, .zero)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let titleFont = UIFont.preferredFont(forTextStyle: .subheadline)
        let baseAmountFont = UIFont.preferredFont(forTextStyle: .largeTitle).bold()
        let measuredAmountWidth = (amountText as NSString).size(
            withAttributes: [.font: baseAmountFont]
        ).width
        let amountScale = measuredAmountWidth > availableWidth && measuredAmountWidth > .zero
            ? availableWidth / measuredAmountWidth
            : 1
        let amountFont = baseAmountFont.withSize(baseAmountFont.pointSize * amountScale)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]
        let amountAttributes: [NSAttributedString.Key: Any] = [
            .font: amountFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        let title = NSAttributedString(string: titleText, attributes: titleAttributes)
        let attributedAmount = NSAttributedString(string: amountText, attributes: amountAttributes)
        let spacing = layoutMargins.top
        let contentHeight = titleFont.lineHeight + spacing + amountFont.lineHeight
        let contentY = chartRect.midY - contentHeight / 2

        title.draw(
            in: CGRect(
                x: chartRect.midX - availableWidth / 2,
                y: contentY,
                width: availableWidth,
                height: titleFont.lineHeight
            )
        )
        attributedAmount.draw(
            in: CGRect(
                x: chartRect.midX - availableWidth / 2,
                y: contentY + titleFont.lineHeight + spacing,
                width: availableWidth,
                height: amountFont.lineHeight
            )
        )
    }

    private func drawLegend(
        segments: [PieChartSegment],
        origin: CGPoint,
        width: CGFloat,
        context: CGContext
    ) {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        let dotDiameter = font.capHeight

        for (index, segment) in segments.enumerated() {
            let rowY = origin.y + CGFloat(index) * legendRowHeight
            let dotRect = CGRect(
                x: origin.x,
                y: rowY + (font.lineHeight - dotDiameter) / 2,
                width: dotDiameter,
                height: dotDiameter
            )
            context.setFillColor(segment.color.cgColor)
            context.fillEllipse(in: dotRect)

            let textX = dotRect.maxX + layoutMargins.left
            let textRect = CGRect(
                x: textX,
                y: rowY,
                width: max(width - textX + origin.x, .zero),
                height: font.lineHeight
            )
            NSAttributedString(string: segment.entity.label, attributes: attributes).draw(in: textRect)
        }
    }

}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
