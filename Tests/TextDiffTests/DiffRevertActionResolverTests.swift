import Foundation
import Testing
@testable import TextDiff

@Test
func candidatesBuildPairedReplacementForAdjacentDeleteInsert() throws {
    let segments = [
        DiffSegment(kind: .delete, tokenKind: .word, text: "old"),
        DiffSegment(kind: .insert, tokenKind: .word, text: "new")
    ]

    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: "old",
        updated: "new"
    )
    #expect(candidates.count == 1)
    #expect(candidates[0].kind == .pairedReplacement)
    #expect(candidates[0].updatedRange == NSRange(location: 0, length: 3))
    #expect(candidates[0].replacementText == "old")

    let action = try #require(DiffRevertActionResolver.action(from: candidates[0], updated: "new"))
    #expect(action.kind == .pairedReplacement)
    #expect(action.resultingUpdated == "old")
}

@Test
func candidatesDoNotPairWhenAnySegmentExistsBetweenDeleteAndInsert() {
    let segments = [
        DiffSegment(kind: .delete, tokenKind: .word, text: "old"),
        DiffSegment(kind: .equal, tokenKind: .whitespace, text: " "),
        DiffSegment(kind: .insert, tokenKind: .word, text: "new")
    ]

    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: "old ",
        updated: " new"
    )
    #expect(candidates.count == 2)
    #expect(candidates[0].kind == .singleDeletion)
    #expect(candidates[1].kind == .singleInsertion)
}

@Test
func singleInsertionActionRemovesInsertedFragment() throws {
    let segments = [
        DiffSegment(kind: .equal, tokenKind: .word, text: "a"),
        DiffSegment(kind: .insert, tokenKind: .word, text: "ß"),
        DiffSegment(kind: .equal, tokenKind: .word, text: "c")
    ]
    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: "ac",
        updated: "aßc"
    )
    let insertion = try #require(candidates.first(where: { $0.kind == .singleInsertion }))

    let action = try #require(DiffRevertActionResolver.action(from: insertion, updated: "aßc"))
    #expect(action.kind == .singleInsertion)
    #expect(action.updatedRange == NSRange(location: 1, length: 1))
    #expect(action.replacementText.isEmpty)
    #expect(action.resultingUpdated == "ac")
}

@Test
func singleDeletionActionReinsertsDeletedFragment() throws {
    let segments = [
        DiffSegment(kind: .equal, tokenKind: .word, text: "a"),
        DiffSegment(kind: .delete, tokenKind: .word, text: "🌍"),
        DiffSegment(kind: .equal, tokenKind: .word, text: "b")
    ]
    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: "a🌍b",
        updated: "ab"
    )
    let deletion = try #require(candidates.first(where: { $0.kind == .singleDeletion }))

    let action = try #require(DiffRevertActionResolver.action(from: deletion, updated: "ab"))
    #expect(action.kind == .singleDeletion)
    #expect(action.updatedRange == NSRange(location: 1, length: 0))
    #expect(action.replacementText == "🌍")
    #expect(action.resultingUpdated == "a🌍b")
}

@Test
func candidatesAreEmptyInCharacterMode() {
    let original = "old value"
    let updated = "new value"
    let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .character)
    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .character,
        original: original,
        updated: updated
    )
    #expect(candidates.isEmpty)
}

@Test
func standaloneDeletionRevertRestoresWordBoundarySpacing() throws {
    let original = "Hello brave world"
    let updated = "Hello world"
    let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .token)

    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: original,
        updated: updated
    )
    let deletion = try #require(candidates.first(where: { $0.kind == .singleDeletion }))

    let action = try #require(DiffRevertActionResolver.action(from: deletion, updated: updated))
    #expect(action.resultingUpdated == original)
}

@Test
func standaloneDeletionAtEndRevertRestoresSpacing() throws {
    let original = "Hello brave"
    let updated = "Hello"
    let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .token)

    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: original,
        updated: updated
    )
    let deletion = try #require(candidates.first(where: { $0.kind == .singleDeletion }))

    let action = try #require(DiffRevertActionResolver.action(from: deletion, updated: updated))
    #expect(action.resultingUpdated == original)
}
