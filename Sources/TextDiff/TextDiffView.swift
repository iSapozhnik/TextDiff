import SwiftUI
import TextDiffCore
import TextDiffUICommon

#if os(macOS)
import AppKit
import TextDiffMacOSUI
#elseif os(iOS)
import UIKit
import TextDiffIOSUI
#endif

/// A SwiftUI view that renders a merged visual diff between two strings.
public struct TextDiffView: View {
    private let result: TextDiffResult?
    private let original: String
    private let updatedValue: String
    private let mode: TextDiffComparisonMode
    private let style: TextDiffStyle

    #if os(macOS)
    private let updatedBinding: Binding<String>?
    private let showsInvisibleCharacters: Bool
    private let isRevertActionsEnabled: Bool
    private let onRevertAction: ((TextDiffRevertAction) -> Void)?
    #endif

    /// Creates a text diff view for two versions of content.
    public init(
        original: String,
        updated: String,
        style: TextDiffStyle = .default,
        mode: TextDiffComparisonMode = .token
    ) {
        self.result = nil
        self.original = original
        self.updatedValue = updated
        self.mode = mode
        self.style = style
        #if os(macOS)
        self.updatedBinding = nil
        self.showsInvisibleCharacters = false
        self.isRevertActionsEnabled = false
        self.onRevertAction = nil
        #endif
    }

    /// Creates a display-only diff view backed by a precomputed result.
    public init(
        result: TextDiffResult,
        style: TextDiffStyle = .default
    ) {
        self.result = result
        self.original = result.original
        self.updatedValue = result.updated
        self.mode = result.mode
        self.style = style
        #if os(macOS)
        self.updatedBinding = nil
        self.showsInvisibleCharacters = false
        self.isRevertActionsEnabled = false
        self.onRevertAction = nil
        #endif
    }

    #if os(macOS)
    /// Creates a macOS-only text diff view backed by a mutable updated binding.
    public init(
        original: String,
        updated: Binding<String>,
        style: TextDiffStyle = .default,
        mode: TextDiffComparisonMode = .token,
        showsInvisibleCharacters: Bool = false,
        isRevertActionsEnabled: Bool = true,
        onRevertAction: ((TextDiffRevertAction) -> Void)? = nil
    ) {
        self.result = nil
        self.original = original
        self.updatedValue = updated.wrappedValue
        self.updatedBinding = updated
        self.mode = mode
        self.style = style
        self.showsInvisibleCharacters = showsInvisibleCharacters
        self.isRevertActionsEnabled = isRevertActionsEnabled
        self.onRevertAction = onRevertAction
    }
    #endif

    public var body: some View {
        #if os(macOS)
        let updated = updatedBinding?.wrappedValue ?? updatedValue
        TextDiffMacOSRepresentable(
            result: result,
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
        #elseif os(iOS)
        TextDiffIOSRepresentable(
            result: result,
            original: original,
            updated: updatedValue,
            style: style,
            mode: mode
        )
        .accessibilityLabel("Text diff")
        #else
        Color.clear.accessibilityHidden(true)
        #endif
    }
}

#if os(macOS)
private struct TextDiffMacOSRepresentable: NSViewRepresentable {
    let result: TextDiffResult?
    let original: String
    let updated: String
    let updatedBinding: Binding<String>?
    let style: TextDiffStyle
    let mode: TextDiffComparisonMode
    let showsInvisibleCharacters: Bool
    let isRevertActionsEnabled: Bool
    let onRevertAction: ((TextDiffRevertAction) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSTextDiffView {
        let view: NSTextDiffView
        if let result {
            view = NSTextDiffView(result: result, style: style)
        } else {
            view = NSTextDiffView(
                original: original,
                updated: updated,
                style: style,
                mode: mode
            )
        }
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        context.coordinator.update(
            updatedBinding: updatedBinding,
            onRevertAction: onRevertAction
        )
        view.showsInvisibleCharacters = showsInvisibleCharacters
        view.isRevertActionsEnabled = result == nil ? isRevertActionsEnabled : false
        view.onRevertAction = { [coordinator = context.coordinator] action in
            coordinator.handle(action)
        }
        return view
    }

    func updateNSView(_ view: NSTextDiffView, context: Context) {
        context.coordinator.update(
            updatedBinding: updatedBinding,
            onRevertAction: onRevertAction
        )
        view.onRevertAction = { [coordinator = context.coordinator] action in
            coordinator.handle(action)
        }
        view.showsInvisibleCharacters = showsInvisibleCharacters
        view.isRevertActionsEnabled = result == nil ? isRevertActionsEnabled : false
        if let result {
            view.setContent(result: result, style: style)
        } else {
            view.setContent(
                original: original,
                updated: updated,
                style: style,
                mode: mode
            )
        }
    }

    final class Coordinator {
        private var updatedBinding: Binding<String>?
        private var onRevertAction: ((TextDiffRevertAction) -> Void)?

        func update(
            updatedBinding: Binding<String>?,
            onRevertAction: ((TextDiffRevertAction) -> Void)?
        ) {
            self.updatedBinding = updatedBinding
            self.onRevertAction = onRevertAction
        }

        func handle(_ action: TextDiffRevertAction) {
            updatedBinding?.wrappedValue = action.resultingUpdated
            onRevertAction?(action)
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

#Preview("TextDiffView") {
    @Previewable @State var updatedText = "Added a diff view. It looks good!"
    let font: PlatformFont = .systemFont(ofSize: 16, weight: .regular)
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
        chipInsets: TextDiffEdgeInsets(top: 1, left: 0, bottom: 1, right: 0),
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
            Text("dog -> fog:")
            TextDiffView(
                original: "dog",
                updated: "fog",
                style: style,
                mode: .character
            )
        }
        Divider()
        Text("Diff by words and revertible")
            .bold()
        TextDiffView(
            original: "Add a diff view! Looks good!",
            updated: $updatedText,
            style: style,
            mode: .token,
            isRevertActionsEnabled: true
        )
        HStack {
            Text("dog -> fog:")
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

#Preview("Precomputed Result") {
    TextDiffView(
        result: TextDiffEngine.result(
            original: "Track deleted text in storage.",
            updated: "Track inserted text in storage.",
            mode: .token
        )
    )
    .padding()
    .frame(width: 360)
}

#Preview("Revert Binding") {
    RevertBindingPreview()
}

#Preview("Height diff") {
    let font: PlatformFont = .systemFont(ofSize: 32, weight: .regular)
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
        chipInsets: TextDiffEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
        interChipSpacing: 1,
        lineSpacing: 0
    )
    ZStack(alignment: .topLeading) {
        Text("Add ed a diff view. It looks good! Add ed a diff view. It looks good!")
            .font(.system(size: 32, weight: .regular))
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
        TextDiffView(
            original: "To switch back to your Mac, press any key on your keyboard.",
            updated: $updated,
            mode: .token,
            isRevertActionsEnabled: true
        )
        .padding()
        .frame(width: 420)
    }
}
#endif

#if os(iOS)
private struct TextDiffIOSRepresentable: UIViewRepresentable {
    let result: TextDiffResult?
    let original: String
    let updated: String
    let style: TextDiffStyle
    let mode: TextDiffComparisonMode

    func makeUIView(context: Context) -> UITextDiffView {
        let view: UITextDiffView
        if let result {
            view = UITextDiffView(result: result, style: style)
        } else {
            view = UITextDiffView(
                original: original,
                updated: updated,
                style: style,
                mode: mode
            )
        }
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: UITextDiffView, context: Context) {
        if let result {
            view.setContent(result: result, style: style)
        } else {
            view.setContent(
                original: original,
                updated: updated,
                style: style,
                mode: mode
            )
        }
    }
}
#endif
