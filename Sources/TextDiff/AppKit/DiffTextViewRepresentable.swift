import AppKit
import SwiftUI

struct DiffTextViewRepresentable: NSViewRepresentable {
    let original: String
    let updated: String
    let style: TextDiffStyle
    let mode: TextDiffComparisonMode

    func makeNSView(context: Context) -> NSTextDiffView {
        let view = NSTextDiffView(
            original: original,
            updated: updated,
            style: style,
            mode: mode
        )
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSTextDiffView, context: Context) {
        view.setContent(
            original: original,
            updated: updated,
            style: style,
            mode: mode
        )
    }
}
