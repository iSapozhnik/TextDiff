import UIKit
import TextDiffCore
import TextDiffUICommon

/// A UIKit view that renders a merged visual diff between two strings.
public final class UITextDiffView: UIView {
    typealias DiffProvider = (String, String, TextDiffComparisonMode) -> [DiffSegment]

    public var original: String {
        didSet {
            guard !isBatchUpdating else { return }
            contentSource = .text
            _ = updateSegmentsIfNeeded()
        }
    }

    public var updated: String {
        didSet {
            guard !isBatchUpdating else { return }
            contentSource = .text
            _ = updateSegmentsIfNeeded()
        }
    }

    public var style: TextDiffStyle {
        didSet {
            guard !isBatchUpdating else {
                pendingStyleInvalidation = true
                return
            }
            invalidateCachedLayout()
        }
    }

    public var mode: TextDiffComparisonMode {
        didSet {
            guard !isBatchUpdating else { return }
            contentSource = .text
            _ = updateSegmentsIfNeeded()
        }
    }

    private var segments: [DiffSegment]
    private let diffProvider: DiffProvider
    private var contentSource: ContentSource
    private var lastOriginal: String
    private var lastUpdated: String
    private var lastModeKey: Int
    private var isBatchUpdating = false
    private var pendingStyleInvalidation = false
    private var cachedWidth: CGFloat = -1
    private var cachedLayout: DiffLayout?

    override public var intrinsicContentSize: CGSize {
        let layout = layoutForCurrentWidth()
        return CGSize(width: UIView.noIntrinsicMetric, height: ceil(layout.contentSize.height))
    }

    public init(
        original: String,
        updated: String,
        style: TextDiffStyle = .default,
        mode: TextDiffComparisonMode = .token
    ) {
        self.original = original
        self.updated = updated
        self.style = style
        self.mode = mode
        self.diffProvider = { original, updated, mode in
            TextDiffEngine.diff(original: original, updated: updated, mode: mode)
        }
        self.contentSource = .text
        self.lastOriginal = original
        self.lastUpdated = updated
        self.lastModeKey = Self.modeKey(for: mode)
        self.segments = self.diffProvider(original, updated, mode)
        super.init(frame: .zero)
        commonInit()
    }

    public init(
        result: TextDiffResult,
        style: TextDiffStyle = .default
    ) {
        self.original = result.original
        self.updated = result.updated
        self.style = style
        self.mode = result.mode
        self.diffProvider = { original, updated, mode in
            TextDiffEngine.diff(original: original, updated: updated, mode: mode)
        }
        self.contentSource = .result
        self.lastOriginal = result.original
        self.lastUpdated = result.updated
        self.lastModeKey = Self.modeKey(for: result.mode)
        self.segments = result.segments
        super.init(frame: .zero)
        commonInit()
    }

    #if TESTING
    init(
        original: String,
        updated: String,
        style: TextDiffStyle = .default,
        mode: TextDiffComparisonMode = .token,
        diffProvider: @escaping DiffProvider
    ) {
        self.original = original
        self.updated = updated
        self.style = style
        self.mode = mode
        self.diffProvider = diffProvider
        self.contentSource = .text
        self.lastOriginal = original
        self.lastUpdated = updated
        self.lastModeKey = Self.modeKey(for: mode)
        self.segments = diffProvider(original, updated, mode)
        super.init(frame: .zero)
        commonInit()
    }
    #endif

    @available(*, unavailable, message: "Use init(original:updated:style:mode:)")
    required init?(coder: NSCoder) {
        fatalError("Use init(original:updated:style:mode:)")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(bounds.width, 1)
        if abs(cachedWidth - width) > 0.5 {
            invalidateCachedLayout()
        }
    }

    public override func draw(_ rect: CGRect) {
        let layout = layoutForCurrentWidth()
        for run in layout.runs {
            if let chipRect = run.chipRect {
                drawChip(
                    chipRect: chipRect,
                    fillColor: run.chipFillColor,
                    strokeColor: run.chipStrokeColor,
                    cornerRadius: run.chipCornerRadius
                )
            }
            run.attributedText.draw(in: run.textRect)
        }
    }

    public func setContent(
        original: String,
        updated: String,
        style: TextDiffStyle,
        mode: TextDiffComparisonMode
    ) {
        isBatchUpdating = true
        defer {
            isBatchUpdating = false
            let needsStyleInvalidation = pendingStyleInvalidation
            pendingStyleInvalidation = false

            contentSource = .text
            let didRecompute = updateSegmentsIfNeeded()
            if needsStyleInvalidation, !didRecompute {
                invalidateCachedLayout()
            }
        }

        self.style = style
        self.mode = mode
        self.original = original
        self.updated = updated
    }

    public func setContent(
        result: TextDiffResult,
        style: TextDiffStyle
    ) {
        isBatchUpdating = true
        defer {
            isBatchUpdating = false
            pendingStyleInvalidation = false
        }

        self.style = style
        apply(result: result)
    }

    @discardableResult
    private func updateSegmentsIfNeeded() -> Bool {
        let newModeKey = Self.modeKey(for: mode)
        guard original != lastOriginal || updated != lastUpdated || newModeKey != lastModeKey else {
            return false
        }

        lastOriginal = original
        lastUpdated = updated
        lastModeKey = newModeKey
        segments = diffProvider(original, updated, mode)
        contentSource = .text
        invalidateCachedLayout()
        return true
    }

    private func apply(result: TextDiffResult) {
        contentSource = .result
        original = result.original
        updated = result.updated
        mode = result.mode
        lastOriginal = result.original
        lastUpdated = result.updated
        lastModeKey = Self.modeKey(for: result.mode)
        segments = result.segments
        invalidateCachedLayout()
    }

    private func layoutForCurrentWidth() -> DiffLayout {
        let width = max(bounds.width, 1)
        if let cachedLayout, abs(cachedWidth - width) <= 0.5 {
            return cachedLayout
        }

        let verticalInset = DiffTextLayoutMetrics.verticalTextInset(for: style)
        let contentInsets = TextDiffEdgeInsets(top: verticalInset, left: 0, bottom: verticalInset, right: 0)
        let availableWidth = max(1, width - contentInsets.left - contentInsets.right)
        let layout = DiffTokenLayouter.layout(
            segments: segments,
            style: style,
            availableWidth: availableWidth,
            contentInsets: contentInsets
        )

        cachedWidth = width
        cachedLayout = layout
        return layout
    }

    private func invalidateCachedLayout() {
        cachedLayout = nil
        cachedWidth = -1
        setNeedsDisplay()
        invalidateIntrinsicContentSize()
    }

    private func drawChip(
        chipRect: CGRect,
        fillColor: PlatformColor?,
        strokeColor: PlatformColor?,
        cornerRadius: CGFloat
    ) {
        guard chipRect.width > 0, chipRect.height > 0 else {
            return
        }

        let fillPath = UIBezierPath(roundedRect: chipRect, cornerRadius: cornerRadius)
        fillColor?.setFill()
        fillPath.fill()

        let strokeRect = chipRect.insetBy(dx: 0.5, dy: 0.5)
        guard strokeRect.width > 0, strokeRect.height > 0 else {
            return
        }

        let strokePath = UIBezierPath(roundedRect: strokeRect, cornerRadius: cornerRadius)
        strokeColor?.setStroke()
        strokePath.lineWidth = 1
        strokePath.stroke()
    }

    private func commonInit() {
        backgroundColor = .clear
        contentMode = .redraw
        isOpaque = false
    }

    private static func modeKey(for mode: TextDiffComparisonMode) -> Int {
        switch mode {
        case .token:
            return 0
        case .character:
            return 1
        }
    }
}

private enum ContentSource {
    case text
    case result
}
