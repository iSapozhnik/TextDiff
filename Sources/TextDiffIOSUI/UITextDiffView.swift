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
            guard !isBatchUpdating else { return }
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

    /// Enables two-tap revert action selection and hit-testing.
    public var isRevertActionsEnabled: Bool = false {
        didSet {
            guard oldValue != isRevertActionsEnabled else {
                return
            }
            guard !contentSource.isResultDriven else {
                return
            }
            invalidateCachedLayout()
        }
    }

    /// Callback invoked when user taps a selected change a second time.
    public var onRevertAction: ((TextDiffRevertAction) -> Void)?

    private var segments: [DiffSegment]
    private let diffProvider: DiffProvider
    private var contentSource: ContentSource
    private var lastOriginal: String
    private var lastUpdated: String
    private var lastModeKey: Int
    private var isBatchUpdating = false
    private var segmentGeneration: Int = 0
    private var cachedWidth: CGFloat = -1
    private var cachedLayout: DiffLayout?
    private var cachedInteractionContext: DiffRevertInteractionContext?
    private var cachedInteractionWidth: CGFloat = -1
    private var cachedInteractionGeneration: Int = -1
    private var selectedActionID: Int?
    private let minimumTapTargetSize = CGSize(width: 44, height: 44)

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
        drawSelectedRevertAffordance(layout: layout)
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

            contentSource = .text
            let didRecompute = updateSegmentsIfNeeded()
            if !didRecompute {
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
        segmentGeneration += 1
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
        segmentGeneration += 1
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
        invalidateInteractionCache()
        return layout
    }

    private func invalidateCachedLayout() {
        cachedLayout = nil
        cachedWidth = -1
        invalidateInteractionCache()
        clearSelection()
        setNeedsDisplay()
        invalidateIntrinsicContentSize()
    }

    private func invalidateInteractionCache() {
        cachedInteractionContext = nil
        cachedInteractionWidth = -1
        cachedInteractionGeneration = -1
    }

    private func interactionContext(for layout: DiffLayout) -> DiffRevertInteractionContext? {
        guard isRevertActionsEnabled, mode == .token, !contentSource.isResultDriven else {
            return nil
        }

        let width = max(bounds.width, 1)
        if let cachedInteractionContext,
           abs(cachedInteractionWidth - width) <= 0.5,
           cachedInteractionGeneration == segmentGeneration {
            return cachedInteractionContext
        }

        let context = DiffRevertActionResolver.interactionContext(
            segments: segments,
            runs: layout.runs,
            mode: mode,
            original: original,
            updated: updated
        )
        cachedInteractionContext = context
        cachedInteractionWidth = width
        cachedInteractionGeneration = segmentGeneration
        return context
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }

        handleTap(at: recognizer.location(in: self))
    }

    private func handleTap(at point: CGPoint) {
        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout) else {
            clearSelection()
            return
        }

        guard let actionID = actionIDForHitTarget(at: point, context: context) else {
            clearSelection()
            return
        }

        if selectedActionID == actionID {
            triggerRevert(actionID, context: context)
        } else {
            selectedActionID = actionID
            setNeedsDisplay()
        }
    }

    private func clearSelection() {
        guard selectedActionID != nil else {
            return
        }
        selectedActionID = nil
        setNeedsDisplay()
    }

    private func triggerRevert(_ actionID: Int, context: DiffRevertInteractionContext) {
        defer {
            clearSelection()
        }
        guard let candidate = context.candidatesByID[actionID],
              let action = DiffRevertActionResolver.action(from: candidate, updated: updated) else {
            return
        }
        setContent(
            original: original,
            updated: action.resultingUpdated,
            style: style,
            mode: mode
        )
        onRevertAction?(action)
    }

    private func actionIDForHitTarget(
        at point: CGPoint,
        context: DiffRevertInteractionContext
    ) -> Int? {
        return DiffRevertHitResolver.actionIDForHitTarget(
            at: point,
            context: context,
            minimumTapTargetSize: minimumTapTargetSize
        )
    }

    private func drawSelectedRevertAffordance(layout: DiffLayout) {
        guard let selectedActionID else {
            return
        }
        guard let context = interactionContext(for: layout),
              let chipRects = context.chipRectsByActionID[selectedActionID],
              !chipRects.isEmpty else {
            return
        }

        tintColor.withAlphaComponent(0.9).setStroke()
        if chipRects.count > 1, let unionRect = context.unionChipRectByActionID[selectedActionID] {
            let groupRect = unionRect.insetBy(dx: -1.5, dy: -1.5)
            let groupPath = UIBezierPath(
                roundedRect: groupRect,
                cornerRadius: style.chipCornerRadius + 2
            )
            applyGroupStrokeStyle(to: groupPath)
            groupPath.stroke()
        } else {
            for chipRect in chipRects {
                let outlineRect = chipRect.insetBy(dx: -1.5, dy: -1.5)
                let outlinePath = UIBezierPath(
                    roundedRect: outlineRect,
                    cornerRadius: style.chipCornerRadius + 1
                )
                applyGroupStrokeStyle(to: outlinePath)
                outlinePath.stroke()
            }
        }
    }

    private func applyGroupStrokeStyle(to path: UIBezierPath) {
        path.lineWidth = 1.5
        switch style.groupStrokeStyle {
        case .solid:
            path.setLineDash(nil, count: 0, phase: 0)
        case .dashed:
            var pattern: [CGFloat] = [4, 2]
            path.setLineDash(&pattern, count: pattern.count, phase: 0)
        }
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
        isUserInteractionEnabled = true
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapRecognizer)
    }

    private static func modeKey(for mode: TextDiffComparisonMode) -> Int {
        switch mode {
        case .token:
            return 0
        case .character:
            return 1
        }
    }

    #if TESTING
    @discardableResult
    func _testingSelectFirstRevertAction() -> Bool {
        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout),
              let firstActionID = context.candidatesByID.keys.sorted().first else {
            return false
        }
        selectedActionID = firstActionID
        setNeedsDisplay()
        return true
    }

    @discardableResult
    func _testingTriggerSelectedRevertAction() -> Bool {
        guard let selectedActionID else {
            return false
        }
        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout),
              context.candidatesByID[selectedActionID] != nil else {
            return false
        }
        triggerRevert(selectedActionID, context: context)
        return true
    }

    func _testingSelectedActionID() -> Int? {
        selectedActionID
    }

    func _testingActionCenters() -> [CGPoint] {
        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout) else {
            return []
        }
        return context.candidatesByID.keys.sorted().compactMap { actionID in
            guard let rect = context.unionChipRectByActionID[actionID] else {
                return nil
            }
            return CGPoint(x: rect.midX, y: rect.midY)
        }
    }

    func _testingTap(at point: CGPoint) {
        handleTap(at: point)
    }
    #endif
}

private enum ContentSource {
    case text
    case result

    var isResultDriven: Bool {
        switch self {
        case .text:
            return false
        case .result:
            return true
        }
    }
}
