import AppKit
import Foundation

final class DiffCanvasView: NSView {
    private var segments: [DiffSegment] = []
    private var style: TextDiffStyle = .default

    private var cachedWidth: CGFloat = -1
    private var cachedLayout: DiffLayout?

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        let layout = layoutForCurrentWidth()
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(layout.contentSize.height))
    }

    override func setFrameSize(_ newSize: NSSize) {
        let previousWidth = frame.width
        super.setFrameSize(newSize)
        if abs(previousWidth - newSize.width) > 0.5 {
            invalidateCachedLayout()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
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

    func update(segments: [DiffSegment], style: TextDiffStyle) {
        self.segments = segments
        self.style = style
        invalidateCachedLayout()
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
}
