import AppKit
import SwiftUI

/// A SwiftUI view that renders a merged visual diff between two strings.
public struct TextDiffView: View {
    private let original: String
    private let updatedValue: String
    private let updatedBinding: Binding<String>?
    private let mode: TextDiffComparisonMode
    private let style: TextDiffStyle
    private let showsInvisibleCharacters: Bool
    private let isRevertActionsEnabled: Bool
    private let onRevertAction: ((TextDiffRevertAction) -> Void)?

    /// Creates a text diff view for two versions of content.
    ///
    /// - Parameters:
    ///   - original: The source text before edits.
    ///   - updated: The source text after edits.
    ///   - style: Visual style used to render additions, deletions, and unchanged text.
    ///   - mode: Comparison mode that controls token-level or character-refined output.
    ///   - showsInvisibleCharacters: Debug-only overlay that draws whitespace/newline symbols in red.
    public init(
        original: String,
        updated: String,
        style: TextDiffStyle = .default,
        mode: TextDiffComparisonMode = .token,
        showsInvisibleCharacters: Bool = false
    ) {
        self.original = original
        self.updatedValue = updated
        self.updatedBinding = nil
        self.mode = mode
        self.style = style
        self.showsInvisibleCharacters = showsInvisibleCharacters
        self.isRevertActionsEnabled = false
        self.onRevertAction = nil
    }

    /// Creates a text diff view backed by a mutable updated binding.
    ///
    /// - Parameters:
    ///   - original: The source text before edits.
    ///   - updated: The source text after edits.
    ///   - style: Visual style used to render additions, deletions, and unchanged text.
    ///   - mode: Comparison mode that controls token-level or character-refined output.
    ///   - showsInvisibleCharacters: Debug-only overlay that draws whitespace/newline symbols in red.
    ///   - isRevertActionsEnabled: Enables hover affordance and revert actions.
    ///   - onRevertAction: Optional callback invoked on revert clicks.
    public init(
        original: String,
        updated: Binding<String>,
        style: TextDiffStyle = .default,
        mode: TextDiffComparisonMode = .token,
        showsInvisibleCharacters: Bool = false,
        isRevertActionsEnabled: Bool = true,
        onRevertAction: ((TextDiffRevertAction) -> Void)? = nil
    ) {
        self.original = original
        self.updatedValue = updated.wrappedValue
        self.updatedBinding = updated
        self.mode = mode
        self.style = style
        self.showsInvisibleCharacters = showsInvisibleCharacters
        self.isRevertActionsEnabled = isRevertActionsEnabled
        self.onRevertAction = onRevertAction
    }

    /// The view body that renders the current diff content.
    public var body: some View {
        let updated = updatedBinding?.wrappedValue ?? updatedValue
        DiffTextViewRepresentable(
            original: original,
            updated: updated,
            updatedBinding: updatedBinding,
            style: style,
            mode: mode,
            showsInvisibleCharacters: showsInvisibleCharacters,
            isRevertActionsEnabled: isRevertActionsEnabled,
            onRevertAction: onRevertAction
        )
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

#Preview("TextDiffView") {
    @Previewable @State var updatedText = "Added a diff view. It looks good!"
    let font: NSFont = .systemFont(ofSize: 16, weight: .regular)
    let style = TextDiffStyle(
        additionsStyle: TextDiffChangeStyle(
            fillColor: .systemGreen.withAlphaComponent(0.28),
            strokeColor: .systemGreen.withAlphaComponent(0.75),
            textColorOverride: .labelColor
        ),
        removalsStyle: TextDiffChangeStyle(
            fillColor: .systemRed.withAlphaComponent(0.24),
            strokeColor: .systemRed.withAlphaComponent(0.75),
            textColorOverride: .secondaryLabelColor,
            strikethrough: true
        ),
        textColor: .labelColor,
        font: font,
        chipCornerRadius: 3,
        chipInsets: NSEdgeInsets(top: 1, left: 0, bottom: 1, right: 0),
        interChipSpacing: 1,
        lineSpacing: 2,
        groupStrokeStyle: .dashed
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
        Text("Diff by words and revertable")
            .bold()
            TextDiffView(
                original: "Add a diff view! Looks good!",
                updated: $updatedText,
                style: style,
                mode: .token,
                isRevertActionsEnabled: true
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

#Preview("Revert Binding") {
    RevertBindingPreview()
}

#Preview("Height diff") {
    let font: NSFont = .systemFont(ofSize: 32, weight: .regular)
    let style = TextDiffStyle(
        additionsStyle: TextDiffChangeStyle(
            fillColor: .systemGreen.withAlphaComponent(0.28),
            strokeColor: .systemGreen.withAlphaComponent(0.75),
            textColorOverride: .labelColor
        ),
        removalsStyle: TextDiffChangeStyle(
            fillColor: .systemRed.withAlphaComponent(0.24),
            strokeColor: .systemRed.withAlphaComponent(0.75),
            textColorOverride: .secondaryLabelColor,
            strikethrough: true
        ),
        textColor: .labelColor,
        font: font,
        chipCornerRadius: 3,
        chipInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
        interChipSpacing: 1,
        lineSpacing: 0
    )
    ZStack(alignment: .topLeading) {
        Text("Add ed a diff view. It looks good! Add ed a diff view. It looks good!")
            .font(.system(size: 32, weight: .regular, design: nil))
            .foregroundStyle(.red.opacity(0.7))
        
        TextDiffView(
            original: "Add ed a diff view. It looks good! Add ed a diff view. It looks good.",
            updated: "Add ed a diff view. It looks good! Add ed a diff view. It looks good!",
            style: style,
            mode: .character
        )
    }
    .padding()
}

private struct RevertBindingPreview: View {
    @State private var updated = "To switch back to your computer, simply press any key on your keyboard."

    var body: some View {
        var style = TextDiffStyle.default
        style.font = .systemFont(ofSize: 13)
        return TextDiffView(
            original: "To switch back to your computer, just press any key on your keyboard.",
            updated: $updated,
            style: style,
            mode: .token,
            showsInvisibleCharacters: false,
            isRevertActionsEnabled: true
        )
        .padding()
        .frame(width: 500)
    }
}
