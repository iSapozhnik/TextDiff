import Foundation
import Testing
import TextDiffCore
@testable import TextDiffUICommon

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
func actionRejectsStaleCandidateRangeWhenUpdatedFragmentNoLongerMatches() {
    let updated = "Can you think of a clearer focus state"
    let currentRange = (updated as NSString).range(of: "clearer")
    let staleRange = NSRange(location: currentRange.location + 5, length: currentRange.length)
    let candidate = DiffRevertCandidate(
        id: 0,
        kind: .pairedReplacement,
        tokenKind: .word,
        segmentIndices: [0, 1],
        updatedRange: staleRange,
        replacementText: "clearmore",
        originalTextFragment: "clearmore",
        updatedTextFragment: "clearer"
    )

    let action = DiffRevertActionResolver.action(from: candidate, updated: updated)

    #expect(action == nil)
}

@Test
func candidateRangesIgnoreDisplayOnlyEqualWhitespace() throws {
    let original = "Delete this Can you think of a clearmore state"
    let updated = "Can you think of a clearer state"
    let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .token)

    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: original,
        updated: updated
    )
    let matchedReplacement = candidates.first { candidate in
        candidate.kind == .pairedReplacement
            && candidate.originalTextFragment == "clearmore"
            && candidate.updatedTextFragment == "clearer"
    }
    let replacement = try #require(matchedReplacement)
    let expectedRange = (updated as NSString).range(of: "clearer")

    #expect(replacement.updatedRange == expectedRange)

    let action = try #require(DiffRevertActionResolver.action(from: replacement, updated: updated))
    #expect(action.resultingUpdated == "Can you think of a clearmore state")
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

@Test
func standaloneDeletionAfterSupplementaryPlaneLetterRestoresSpacing() throws {
    let original = "𐐀 cat"
    let updated = "𐐀"
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
func hyphenReplacingWhitespaceRevertRestoresOriginalSpacing() throws {
    let original = "in app purchase"
    let updated = "in-app purchase"
    let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .token)

    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: original,
        updated: updated
    )
    let replacement = try #require(candidates.first(where: { $0.kind == .pairedReplacement }))

    #expect(replacement.originalTextFragment == " ")
    #expect(replacement.updatedTextFragment == "-")

    let action = try #require(DiffRevertActionResolver.action(from: replacement, updated: updated))
    #expect(action.kind == .pairedReplacement)
    #expect(action.resultingUpdated == original)
}

@Test
func singleInsertionWordRevertCollapsesBoundaryWhitespace() throws {
    let original = "A B"
    let updated = "A X B"
    let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .token)

    let candidates = DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: original,
        updated: updated
    )
    let insertion = try #require(candidates.first(where: {
        $0.kind == .singleInsertion && $0.updatedTextFragment == "X"
    }))

    let action = try #require(DiffRevertActionResolver.action(from: insertion, updated: updated))
    #expect(action.resultingUpdated == original)
}

@Test
func sequentialRevertsKeepLooksItAsPairedReplacement() throws {
    let original = "Add a diff view! Looks good!"
    var updated = "Added a diff view. It looks good!"

    updated = try applyingRevert(
        original: original,
        updated: updated,
        kind: .pairedReplacement,
        originalFragment: "Add",
        updatedFragment: "Added"
    )

    updated = try applyingRevert(
        original: original,
        updated: updated,
        kind: .pairedReplacement,
        originalFragment: "!",
        updatedFragment: "."
    )

    updated = try applyingRevert(
        original: original,
        updated: updated,
        kind: .singleInsertion,
        originalFragment: nil,
        updatedFragment: "looks"
    )
    #expect(updated == "Add a diff view! It good!")

    let remaining = revertCandidates(original: original, updated: updated)
    let looksItPair = remaining.first {
        $0.kind == .pairedReplacement
            && $0.originalTextFragment == "Looks"
            && $0.updatedTextFragment == "It"
    }

    #expect(looksItPair != nil)
    #expect(!remaining.contains {
        $0.kind == .singleDeletion && $0.originalTextFragment == "Looks"
    })
    #expect(!remaining.contains {
        $0.kind == .singleInsertion && $0.updatedTextFragment == "It"
    })
}

private func applyingRevert(
    original: String,
    updated: String,
    kind: DiffRevertCandidateKind,
    originalFragment: String?,
    updatedFragment: String?
) throws -> String {
    let candidates = revertCandidates(original: original, updated: updated)
    var matched: DiffRevertCandidate?
    for candidate in candidates {
        guard candidate.kind == kind else {
            continue
        }
        guard candidate.originalTextFragment == originalFragment else {
            continue
        }
        guard candidate.updatedTextFragment == updatedFragment else {
            continue
        }
        matched = candidate
        break
    }

    let candidate = try #require(matched)
    let action = try #require(DiffRevertActionResolver.action(from: candidate, updated: updated))
    return action.resultingUpdated
}

private func revertCandidates(original: String, updated: String) -> [DiffRevertCandidate] {
    let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .token)
    return DiffRevertActionResolver.candidates(
        from: segments,
        mode: .token,
        original: original,
        updated: updated
    )
}
