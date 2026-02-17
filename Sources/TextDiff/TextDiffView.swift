import AppKit
import SwiftUI

public struct TextDiffView: View {
    private let segments: [DiffSegment]
    private let style: TextDiffStyle

    public init(original: String, updated: String, style: TextDiffStyle = .default) {
        self.segments = TextDiffEngine.diff(original: original, updated: updated)
        self.style = style
    }

    public var body: some View {
        DiffTextViewRepresentable(segments: segments, style: style)
            .accessibilityLabel("Text diff")
    }
}

#Preview("Default") {
    TextDiffView(
        original: "Apply old value in this sentence.",
        updated: "Apply new value in this sentence."
    )
    .padding()
    .frame(width: 500)
}

#Preview("Custom Style") {
    TextDiffView(
        original: "Add a diff view! Looks good!",
        updated: "I added a diff view. It looks good!",
        style: TextDiffStyle(
            additionFillColor: NSColor.systemGreen.withAlphaComponent(0.28),
            additionStrokeColor: NSColor.systemGreen.withAlphaComponent(0.75),
            additionTextColorOverride: .labelColor,
            deletionFillColor: NSColor.systemRed.withAlphaComponent(0.24),
            deletionStrokeColor: NSColor.systemRed.withAlphaComponent(0.75),
            deletionTextColorOverride: .secondaryLabelColor,
            unchangedTextColor: .labelColor,
            font: .systemFont(ofSize: 16, weight: .regular),
            chipCornerRadius: 3,
            chipInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            deletionStrikethrough: true,
            interChipSpacing: 1
        )
    )
    .padding()
    .frame(width: 300)
}

#Preview("Punctuation Replacement") {
    TextDiffView(
        original: "Wait!",
        updated: "Wait."
    )
    .padding()
    .frame(width: 320)
}
