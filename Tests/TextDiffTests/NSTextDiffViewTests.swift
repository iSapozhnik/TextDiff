import Testing
@testable import TextDiff

@Test
@MainActor
func nsTextDiffViewInitComputesExactlyOnce() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    #expect(callCount == 1)
    #expect(view.intrinsicContentSize.height > 0)
}

@Test
@MainActor
func nsTextDiffViewRecomputesWhenOriginalChanges() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    view.original = "old-2"

    #expect(callCount == 2)
}

@Test
@MainActor
func nsTextDiffViewRecomputesWhenUpdatedChanges() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    view.updated = "new-2"

    #expect(callCount == 2)
}

@Test
@MainActor
func nsTextDiffViewRecomputesWhenModeChanges() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    view.mode = .character

    #expect(callCount == 2)
}

@Test
@MainActor
func nsTextDiffViewStyleChangeDoesNotRecomputeDiff() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    var style = TextDiffStyle.default
    style.deletionStrikethrough = true
    view.style = style

    #expect(callCount == 1)
}
