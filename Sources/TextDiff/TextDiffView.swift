import AppKit
import SwiftUI

/// A SwiftUI view that renders a merged visual diff between two strings.
public struct TextDiffView: View {
    private let original: String
    private let updated: String
    private let mode: TextDiffComparisonMode
    private let style: TextDiffStyle
    @StateObject private var model: TextDiffViewModel

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
        self.mode = mode
        self.style = style
        _model = StateObject(
            wrappedValue: TextDiffViewModel(original: original, updated: updated, mode: mode)
        )
    }

    /// The view body that renders the current diff content.
    public var body: some View {
        DiffTextViewRepresentable(segments: model.segments, style: style)
            .accessibilityLabel("Text diff")
            .onChange(of: original) { _, _ in
                model.updateIfNeeded(original: original, updated: updated, mode: mode)
            }
            .onChange(of: updated) { _, _ in
                model.updateIfNeeded(original: original, updated: updated, mode: mode)
            }
            .onChange(of: modeKey) { _, _ in
                model.updateIfNeeded(original: original, updated: updated, mode: mode)
            }
    }

    private var modeKey: Int {
        switch mode {
        case .token:
            return 0
        case .character:
            return 1
        }
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
    let style = TextDiffStyle(
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
        interChipSpacing: 1,
        lineSpacing: 2
    )
    VStack(alignment: .leading, spacing: 4) {
        Text("Diff by characters")
            .bold()
        TextDiffView(
            original: "Add a diff view! Looks good!",
            updated: "Added a diff view. It looks good!",
            style: style,
            mode: .character
        )
        HStack {
            Text("dog → fog:")
            TextDiffView(
                original: "dog",
                updated: "fog",
                style: style,
                mode: .character
            )
        }
        Divider()
        Text("Diff by words")
            .bold()
        TextDiffView(
            original: "Add a diff view! Looks good!",
            updated: "Added a diff view. It looks good!",
            style: style,
            mode: .token
        )
        HStack {
            Text("dog → fog:")
            TextDiffView(
                original: "dog",
                updated: "fog",
                style: style,
                mode: .token
            )
        }
    }
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

#Preview("Character Mode") {
    TextDiffView(
        original: "Add a diff",
        updated: "Added a diff",
        mode: .character
    )
    .padding()
    .frame(width: 320)
}
