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

    /// Enables hover affordances and revert action hit-testing.
    public var isRevertActionsEnabled: Bool = false {
        didSet {
            guard oldValue != isRevertActionsEnabled else {
                return
            }
            invalidateCachedLayout()
        }
    }

    /// Callback invoked when user clicks the revert icon.
    public var onRevertAction: ((TextDiffRevertAction) -> Void)?

    private var segments: [DiffSegment]
    private let diffProvider: DiffProvider

    private var lastOriginal: String
    private var lastUpdated: String
    private var lastModeKey: Int
    private var isBatchUpdating = false
    private var pendingStyleInvalidation = false
    private var segmentGeneration: Int = 0

    private var cachedWidth: CGFloat = -1
    private var cachedLayout: DiffLayout?

    private var cachedInteractionContext: DiffRevertInteractionContext?
    private var cachedInteractionWidth: CGFloat = -1
    private var cachedInteractionGeneration: Int = -1

    private var trackedArea: NSTrackingArea?
    private var hoveredActionID: Int?
    private var hoveredIconRect: CGRect?
    private let hoverDismissDelay: TimeInterval = 0.5
    private var pendingHoverDismissWorkItem: DispatchWorkItem?
    private var hoverDismissGeneration: Int = 0
    private var isPointingHandCursorActive = false

    #if TESTING
    private var testingHoverDismissScheduler: ((TimeInterval, @escaping () -> Void) -> Void)?
    private var testingScheduledHoverDismissBlocks: [() -> Void] = []
    #endif

    private let hoverOutlineColor = NSColor.controlAccentColor.withAlphaComponent(0.9)
    private let hoverButtonFillColor = NSColor.black
    private let hoverButtonStrokeColor = NSColor.clear
    private let hoverIconName = "arrow.turn.down.left"
    private let hoverButtonSize = CGSize(width: 16, height: 16)
    private let hoverButtonGap: CGFloat = 4

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

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackedArea {
            removeTrackingArea(trackedArea)
        }
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeInKeyWindow,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackedArea = area
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

        drawHoveredRevertAffordance(layout: layout)
    }

    override public func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let location = convert(event.locationInWindow, from: nil)
        updateHoverState(location: location)
    }

    override public func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        scheduleHoverDismiss()
    }

    override public func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if handleIconClick(at: location) {
            return
        }
        super.mouseDown(with: event)
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
        segmentGeneration += 1
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
        invalidateInteractionCache()
        return layout
    }

    private func interactionContext(for layout: DiffLayout) -> DiffRevertInteractionContext? {
        guard isRevertActionsEnabled, mode == .token else {
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

    private func invalidateCachedLayout() {
        cachedLayout = nil
        cachedWidth = -1
        invalidateInteractionCache()
        cancelPendingHoverDismiss()
        clearHoverStateNow()
        needsDisplay = true
        invalidateIntrinsicContentSize()
    }

    private func invalidateInteractionCache() {
        cachedInteractionContext = nil
        cachedInteractionWidth = -1
        cachedInteractionGeneration = -1
    }

    private func updateHoverState(location: CGPoint) {
        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout) else {
            cancelPendingHoverDismiss()
            clearHoverStateNow()
            return
        }

        if let actionID = actionIDForHitTarget(at: location, layout: layout, context: context) {
            let iconRect = iconRect(for: actionID, context: context)
            if hoveredActionID == actionID {
                cancelPendingHoverDismiss()
                applyImmediateHover(actionID: actionID, iconRect: iconRect)
            } else {
                switchHoverImmediately(to: actionID, iconRect: iconRect)
            }
            setPointingHandCursorActive(iconRect?.contains(location) == true)
            return
        }

        setPointingHandCursorActive(false)
        scheduleHoverDismiss()
    }

    private func clearHoverState() {
        cancelPendingHoverDismiss()
        clearHoverStateNow()
    }

    private func clearHoverStateNow() {
        guard hoveredActionID != nil || hoveredIconRect != nil || isPointingHandCursorActive else {
            return
        }
        hoveredActionID = nil
        hoveredIconRect = nil
        setPointingHandCursorActive(false)
        needsDisplay = true
    }

    private func applyImmediateHover(actionID: Int, iconRect: CGRect?) {
        let didChangeHover = hoveredActionID != actionID || hoveredIconRect != iconRect
        hoveredActionID = actionID
        hoveredIconRect = iconRect
        if didChangeHover {
            needsDisplay = true
        }
    }

    private func switchHoverImmediately(to actionID: Int, iconRect: CGRect?) {
        cancelPendingHoverDismiss()
        applyImmediateHover(actionID: actionID, iconRect: iconRect)
    }

    private func cancelPendingHoverDismiss() {
        pendingHoverDismissWorkItem?.cancel()
        pendingHoverDismissWorkItem = nil
        hoverDismissGeneration += 1
    }

    private func scheduleHoverDismiss() {
        guard pendingHoverDismissWorkItem == nil else {
            return
        }

        hoverDismissGeneration += 1
        let generation = hoverDismissGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            guard self.hoverDismissGeneration == generation else {
                return
            }
            self.pendingHoverDismissWorkItem = nil
            self.clearHoverStateNow()
        }
        pendingHoverDismissWorkItem = workItem

        #if TESTING
        if let testingHoverDismissScheduler {
            testingHoverDismissScheduler(hoverDismissDelay) {
                workItem.perform()
            }
            return
        }
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDismissDelay) {
            workItem.perform()
        }
    }

    private func setPointingHandCursorActive(_ isActive: Bool) {
        guard isPointingHandCursorActive != isActive else {
            return
        }
        isPointingHandCursorActive = isActive
        if isActive {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }

    @discardableResult
    private func handleIconClick(at location: CGPoint) -> Bool {
        guard isRevertActionsEnabled, mode == .token else {
            return false
        }

        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout),
              let actionID = actionIDForHitTarget(at: location, layout: layout, context: context) else {
            return false
        }

        guard let candidate = context.candidatesByID[actionID] else {
            return false
        }

        if let action = DiffRevertActionResolver.action(from: candidate, updated: updated) {
            onRevertAction?(action)
        }
        return true
    }

    private func actionIDForHitTarget(
        at point: CGPoint,
        layout: DiffLayout,
        context: DiffRevertInteractionContext
    ) -> Int? {
        for actionID in context.candidatesByID.keys.sorted() {
            let includeIcon = hoveredActionID == actionID
            if isPointWithinActionHitTarget(
                point,
                actionID: actionID,
                layout: layout,
                context: context,
                includeIcon: includeIcon
            ) {
                return actionID
            }
        }
        return nil
    }

    private func isPointWithinActionHitTarget(
        _ point: CGPoint,
        actionID: Int,
        layout: DiffLayout,
        context: DiffRevertInteractionContext,
        includeIcon: Bool
    ) -> Bool {
        if let runIndices = context.runIndicesByActionID[actionID] {
            for runIndex in runIndices {
                guard layout.runs.indices.contains(runIndex),
                      let chipRect = layout.runs[runIndex].chipRect else {
                    continue
                }
                if chipRect.contains(point) {
                    return true
                }
            }
        }

        if includeIcon, let iconRect = iconRect(for: actionID, context: context), iconRect.contains(point) {
            return true
        }

        return false
    }

    private func actionID(at point: CGPoint, layout: DiffLayout, context: DiffRevertInteractionContext) -> Int? {
        for actionID in context.runIndicesByActionID.keys.sorted() {
            guard let runIndices = context.runIndicesByActionID[actionID] else {
                continue
            }
            for runIndex in runIndices {
                guard layout.runs.indices.contains(runIndex),
                      let chipRect = layout.runs[runIndex].chipRect else {
                    continue
                }
                if chipRect.contains(point) {
                    return actionID
                }
            }
        }
        return nil
    }

    private func iconRect(for actionID: Int, context: DiffRevertInteractionContext) -> CGRect? {
        guard let unionRect = context.unionChipRectByActionID[actionID] else {
            return nil
        }

        let maxX = bounds.maxX - hoverButtonSize.width - 2
        var originX = unionRect.maxX + hoverButtonGap
        if originX > maxX {
            originX = max(bounds.minX + 2, unionRect.maxX - hoverButtonSize.width)
        }

        var originY = unionRect.midY - (hoverButtonSize.height / 2)
        originY = max(bounds.minY + 2, min(originY, bounds.maxY - hoverButtonSize.height - 2))

        return CGRect(origin: CGPoint(x: originX, y: originY), size: hoverButtonSize)
    }

    private func drawHoveredRevertAffordance(layout: DiffLayout) {
        guard let hoveredActionID else {
            return
        }
        guard let context = interactionContext(for: layout),
              let chipRects = context.chipRectsByActionID[hoveredActionID],
              !chipRects.isEmpty else {
            return
        }

        hoverOutlineColor.setStroke()
        if chipRects.count > 1, let unionRect = context.unionChipRectByActionID[hoveredActionID] {
            let groupRect = unionRect.insetBy(dx: -1.5, dy: -1.5)
            let groupPath = NSBezierPath(
                roundedRect: groupRect,
                xRadius: style.chipCornerRadius + 2,
                yRadius: style.chipCornerRadius + 2
            )
            applyGroupStrokeStyle(to: groupPath)
            groupPath.stroke()
        } else {
            for chipRect in chipRects {
                let outlineRect = chipRect.insetBy(dx: -1.5, dy: -1.5)
                let outlinePath = NSBezierPath(
                    roundedRect: outlineRect,
                    xRadius: style.chipCornerRadius + 1,
                    yRadius: style.chipCornerRadius + 1
                )
                applyGroupStrokeStyle(to: outlinePath)
                outlinePath.stroke()
            }
        }

        let iconRect = hoveredIconRect ?? iconRect(for: hoveredActionID, context: context)
        guard let iconRect else {
            return
        }
        drawIconButton(in: iconRect)
    }

    private func drawIconButton(in rect: CGRect) {
        let buttonPath = NSBezierPath(ovalIn: rect)
        hoverButtonFillColor.setFill()
        buttonPath.fill()
        hoverButtonStrokeColor.setStroke()
        buttonPath.lineWidth = 1
        buttonPath.stroke()

        let symbolRect = rect.insetBy(dx: 4, dy: 4)

        let base = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        let white = NSImage.SymbolConfiguration(hierarchicalColor: .white)
        let config = base
            .applying(.preferringMonochrome())
            .applying(white)

        guard let icon = NSImage(systemSymbolName: hoverIconName, accessibilityDescription: "Revert"),
              let configured = icon.withSymbolConfiguration(config) else {
            return
        }
        configured.draw(in: symbolRect)
    }

    private func applyGroupStrokeStyle(to path: NSBezierPath) {
        path.lineWidth = 1.5
        switch style.groupStrokeStyle {
        case .solid:
            path.setLineDash([], count: 0, phase: 0)
        case .dashed:
            var pattern: [CGFloat] = [4, 2]
            path.setLineDash(&pattern, count: pattern.count, phase: 0)
        }
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

    #if TESTING
    @discardableResult
    func _testingSetHoveredFirstRevertAction() -> Bool {
        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout),
              let firstActionID = context.candidatesByID.keys.sorted().first else {
            return false
        }
        cancelPendingHoverDismiss()
        hoveredActionID = firstActionID
        hoveredIconRect = iconRect(for: firstActionID, context: context)
        needsDisplay = true
        return true
    }

    @discardableResult
    func _testingTriggerHoveredRevertAction() -> Bool {
        guard let hoveredActionID else {
            return false
        }
        let layout = layoutForCurrentWidth()
        guard let context = interactionContext(for: layout),
              let candidate = context.candidatesByID[hoveredActionID] else {
            return false
        }
        if let action = DiffRevertActionResolver.action(from: candidate, updated: updated) {
            onRevertAction?(action)
        }
        return true
    }

    func _testingHasInteractionContext() -> Bool {
        let layout = layoutForCurrentWidth()
        return interactionContext(for: layout) != nil
    }

    func _testingHoveredActionID() -> Int? {
        hoveredActionID
    }

    func _testingHasPendingHoverDismiss() -> Bool {
        pendingHoverDismissWorkItem != nil
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

    func _testingUpdateHover(location: CGPoint) {
        updateHoverState(location: location)
    }

    func _testingEnableManualHoverDismissScheduler() {
        testingScheduledHoverDismissBlocks.removeAll()
        testingHoverDismissScheduler = { [weak self] _, block in
            self?.testingScheduledHoverDismissBlocks.append(block)
        }
    }

    @discardableResult
    func _testingRunNextScheduledHoverDismiss() -> Bool {
        guard !testingScheduledHoverDismissBlocks.isEmpty else {
            return false
        }
        let block = testingScheduledHoverDismissBlocks.removeFirst()
        block()
        return true
    }

    func _testingClearManualHoverDismissScheduler() {
        testingHoverDismissScheduler = nil
        testingScheduledHoverDismissBlocks.removeAll()
    }
    #endif
}
