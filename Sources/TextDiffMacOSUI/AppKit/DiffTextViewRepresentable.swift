import AppKit
import SwiftUI
import TextDiffCore

struct DiffTextViewRepresentable: NSViewRepresentable {
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
