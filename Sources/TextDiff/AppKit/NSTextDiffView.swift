import AppKit
import Foundation

/// An AppKit view that renders a merged visual diff between two strings.
public final class NSTextDiffView: NSView {
    typealias DiffProvider = (String, String, TextDiffComparisonMode) -> [DiffSegment]

    /// The source text before edits.
    /// Setting this value updates rendered diff output when content changes.
    public var original: String {
        didSet {
            guard !isBatchUpdating else {
                return
            }
            _ = updateSegmentsIfNeeded()
        }
    }

    /// The source text after edits.
    /// Setting this value updates rendered diff output when content changes.
    public var updated: String {
        didSet {
            guard !isBatchUpdating else {
                return
            }
            _ = updateSegmentsIfNeeded()
        }
    }

    /// Visual style used to render additions, deletions, and unchanged text.
    /// Setting this value redraws the view without recomputing diff segments.
    public var style: TextDiffStyle {
        didSet {
            guard !isBatchUpdating else {
                pendingStyleInvalidation = true
                return
            }
            invalidateCachedLayout()
        }
    }

    /// Comparison mode that controls token-level or character-refined output.
    /// Setting this value updates rendered diff output when mode changes.
    public var mode: TextDiffComparisonMode {
        didSet {
            guard !isBatchUpdating else {
                return
            }
            _ = updateSegmentsIfNeeded()
        }
    }

    private var segments: [DiffSegment]
    private let diffProvider: DiffProvider

    private var lastOriginal: String
    private var lastUpdated: String
    private var lastModeKey: Int
    private var isBatchUpdating = false
    private var pendingStyleInvalidation = false

    private var cachedWidth: CGFloat = -1
    private var cachedLayout: DiffLayout?

    override public var isFlipped: Bool {
        true
    }

    override public var intrinsicContentSize: NSSize {
        let layout = layoutForCurrentWidth()
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(layout.contentSize.height))
    }

    /// Creates a text diff view for two versions of content.
    ///
    /// - Parameters:
    ///   - original: The source text before edits.
    ///   - updated: The source text after edits.
    ///   - style: Visual style used to render additions, deletions, and unchanged text.
    ///   - mode: Comparison mode that controls token-level or character-refined output.
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
        self.lastOriginal = original
        self.lastUpdated = updated
        self.lastModeKey = Self.modeKey(for: mode)
        self.segments = self.diffProvider(original, updated, mode)
        super.init(frame: .zero)
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
        self.lastOriginal = original
        self.lastUpdated = updated
        self.lastModeKey = Self.modeKey(for: mode)
        self.segments = diffProvider(original, updated, mode)
        super.init(frame: .zero)
    }
    #endif

    @available(*, unavailable, message: "Use init(original:updated:style:mode:)")
    required init?(coder: NSCoder) {
        fatalError("Use init(original:updated:style:mode:)")
    }

    override public func setFrameSize(_ newSize: NSSize) {
        let previousWidth = frame.width
        super.setFrameSize(newSize)
        if abs(previousWidth - newSize.width) > 0.5 {
            invalidateCachedLayout()
        }
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

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

    /// Atomically updates view inputs and recomputes diff segments at most once.
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
        invalidateCachedLayout()
        return true
    }

    private func layoutForCurrentWidth() -> DiffLayout {
        let width = max(bounds.width, 1)
        if let cachedLayout, abs(cachedWidth - width) <= 0.5 {
            return cachedLayout
        }

        let verticalInset = DiffTextLayoutMetrics.verticalTextInset(for: style)
        let contentInsets = NSEdgeInsets(top: verticalInset, left: 0, bottom: verticalInset, right: 0)
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
        needsDisplay = true
        invalidateIntrinsicContentSize()
    }

    private func drawChip(
        chipRect: CGRect,
        fillColor: NSColor?,
        strokeColor: NSColor?,
        cornerRadius: CGFloat
    ) {
        guard chipRect.width > 0, chipRect.height > 0 else {
            return
        }

        let fillPath = NSBezierPath(roundedRect: chipRect, xRadius: cornerRadius, yRadius: cornerRadius)
        fillColor?.setFill()
        fillPath.fill()

        let strokeRect = chipRect.insetBy(dx: 0.5, dy: 0.5)
        guard strokeRect.width > 0, strokeRect.height > 0 else {
            return
        }

        let strokePath = NSBezierPath(roundedRect: strokeRect, xRadius: cornerRadius, yRadius: cornerRadius)
        strokeColor?.setStroke()
        strokePath.lineWidth = 1
        strokePath.stroke()
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
