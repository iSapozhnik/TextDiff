import AppKit
import SwiftUI

enum DiffTextLayoutMetrics {
    static func verticalTextInset(for style: TextDiffStyle) -> CGFloat {
        ceil(max(2, style.chipInsets.top + 2, style.chipInsets.bottom + 2))
    }

    static func lineHeight(for style: TextDiffStyle) -> CGFloat {
        let textHeight = ceil(style.font.ascender - style.font.descender + style.font.leading)
        let chipHeight = textHeight + style.chipInsets.top + style.chipInsets.bottom
        return ceil(chipHeight + max(0, style.lineSpacing))
    }
}

struct DiffTextViewRepresentable: NSViewRepresentable {
    let segments: [DiffSegment]
    let style: TextDiffStyle

    func makeNSView(context: Context) -> DiffCanvasView {
        let view = DiffCanvasView()
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.update(segments: segments, style: style)
        return view
    }

    func updateNSView(_ view: DiffCanvasView, context: Context) {
        view.update(segments: segments, style: style)
    }
}
