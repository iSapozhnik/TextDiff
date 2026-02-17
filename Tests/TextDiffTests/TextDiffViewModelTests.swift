import Testing
@testable import TextDiff

@Test
@MainActor
func initComputesExactlyOnce() {
    var callCount = 0
    let model = TextDiffViewModel(original: "old", updated: "new", mode: .token) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "computed")]
    }

    #expect(callCount == 1)
    #expect(model.segments == [DiffSegment(kind: .equal, tokenKind: .word, text: "computed")])
}

@Test
@MainActor
func updateIfNeededDoesNothingForIdenticalInputs() {
    var callCount = 0
    let model = TextDiffViewModel(original: "old", updated: "new", mode: .token) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    model.updateIfNeeded(original: "old", updated: "new", mode: .token)

    #expect(callCount == 1)
    #expect(model.segments == [DiffSegment(kind: .equal, tokenKind: .word, text: "1")])
}

@Test
@MainActor
func updateIfNeededRecomputesWhenOriginalChanges() {
    var callCount = 0
    let model = TextDiffViewModel(original: "old", updated: "new", mode: .token) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    model.updateIfNeeded(original: "old-2", updated: "new", mode: .token)

    #expect(callCount == 2)
    #expect(model.segments == [DiffSegment(kind: .equal, tokenKind: .word, text: "2")])
}

@Test
@MainActor
func updateIfNeededRecomputesWhenUpdatedChanges() {
    var callCount = 0
    let model = TextDiffViewModel(original: "old", updated: "new", mode: .token) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    model.updateIfNeeded(original: "old", updated: "new-2", mode: .token)

    #expect(callCount == 2)
    #expect(model.segments == [DiffSegment(kind: .equal, tokenKind: .word, text: "2")])
}

@Test
@MainActor
func updateIfNeededRecomputesWhenModeChanges() {
    var callCount = 0
    let model = TextDiffViewModel(original: "old", updated: "new", mode: .token) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    model.updateIfNeeded(original: "old", updated: "new", mode: .character)

    #expect(callCount == 2)
    #expect(model.segments == [DiffSegment(kind: .equal, tokenKind: .word, text: "2")])
}

@Test
@MainActor
func styleChangesAreOutOfScopeForModel() {
    var callCount = 0
    let model = TextDiffViewModel(original: "same", updated: "value", mode: .token) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "stable")]
    }

    // Simulate a parent style-only update by re-checking unchanged inputs.
    model.updateIfNeeded(original: "same", updated: "value", mode: .token)

    #expect(callCount == 1)
    #expect(model.segments == [DiffSegment(kind: .equal, tokenKind: .word, text: "stable")])
}
