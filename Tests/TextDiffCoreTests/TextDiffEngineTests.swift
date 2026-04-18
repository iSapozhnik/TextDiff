import Testing
@testable import TextDiffCore

@Test
func equalTextProducesOnlyEqualSegments() {
    let original = "Hello, world!"
    let segments = TextDiffEngine.diff(original: original, updated: original)

    #expect(segments.allSatisfy { $0.kind == .equal })
    #expect(joinedText(segments) == original)
}

@Test
func insertionCreatesInsertWordSegment() {
    let segments = TextDiffEngine.diff(original: "Hello world", updated: "Hello brave world")

    #expect(joinedText(segments) == "Hello brave world")
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .word && $0.text == "brave" })
}

@Test
func deletionCreatesDeleteWordSegment() {
    let segments = TextDiffEngine.diff(original: "Hello brave world", updated: "Hello world")

    #expect(joinedText(segments) == "Hello brave world")
    #expect(segments.contains { $0.kind == .delete && $0.tokenKind == .word && $0.text == "brave" })
}

@Test
func replacementRendersDeleteThenInsert() {
    let segments = TextDiffEngine.diff(original: "old value", updated: "new value")

    let deleteIndex = segments.firstIndex { $0.kind == .delete && $0.tokenKind == .word && $0.text == "old" }
    let insertIndex = segments.firstIndex { $0.kind == .insert && $0.tokenKind == .word && $0.text == "new" }

    #expect(deleteIndex != nil)
    #expect(insertIndex != nil)
    #expect((deleteIndex ?? 0) < (insertIndex ?? 0))
    #expect(joinedText(segments) == "oldnew value")
}

@Test
func punctuationEditsAreLexicalDiffSegments() {
    let segments = TextDiffEngine.diff(original: "Hello, world!", updated: "Hello. world?")

    #expect(segments.contains { $0.kind == .delete && $0.tokenKind == .punctuation && $0.text == "," })
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .punctuation && $0.text == "." })
    #expect(segments.contains { $0.kind == .delete && $0.tokenKind == .punctuation && $0.text == "!" })
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .punctuation && $0.text == "?" })
    #expect(joinedText(segments) == "Hello,. world!?")
}

@Test
func punctuationInsertionReplacingWhitespaceKeepsWhitespaceDeletionVisible() {
    let segments = TextDiffEngine.diff(
        original: "in app purchase",
        updated: "in-app purchase"
    )

    let deletedWhitespaceIndex = segments.firstIndex {
        $0.kind == .delete && $0.tokenKind == .whitespace && $0.text == " "
    }
    let insertedHyphenIndex = segments.firstIndex {
        $0.kind == .insert && $0.tokenKind == .punctuation && $0.text == "-"
    }

    #expect(deletedWhitespaceIndex != nil)
    #expect(insertedHyphenIndex != nil)
    #expect((deletedWhitespaceIndex ?? 0) < (insertedHyphenIndex ?? 0))
}

@Test
func whitespaceOnlyChangesPreserveUpdatedLayoutWithoutWhitespaceDiffMarkers() {
    let updated = "Hello world\n"
    let segments = TextDiffEngine.diff(original: "Hello   world", updated: updated)

    #expect(joinedText(segments) == updated)
    #expect(segments.filter { $0.tokenKind == .whitespace }.allSatisfy { $0.kind == .equal })
}

@Test
func repeatedTokenCaseUsesDeterministicLeftBiasedMatching() {
    let segments = TextDiffEngine.diff(original: "A A B", updated: "A B")
    let wordSegments = segments.filter { $0.tokenKind == .word }

    #expect(wordSegments.count == 3)
    #expect(wordSegments[0] == DiffSegment(kind: .equal, tokenKind: .word, text: "A"))
    #expect(wordSegments[1] == DiffSegment(kind: .delete, tokenKind: .word, text: "A"))
    #expect(wordSegments[2] == DiffSegment(kind: .equal, tokenKind: .word, text: "B"))
    #expect(joinedText(segments) == "A A B")
}

@Test
func multilineInputPreservesNewlinesAndInsertions() {
    let updated = "line1\nlineX\nline2"
    let segments = TextDiffEngine.diff(original: "line1\nline2", updated: updated)

    #expect(joinedText(segments) == updated)
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .word && $0.text == "lineX" })
}

@Test
func multilingualInputProducesStableOutput() {
    let updated = "Привет, мир!"
    let segments = TextDiffEngine.diff(original: "Привет мир", updated: updated)

    #expect(!segments.isEmpty)
    #expect(joinedText(segments) == updated)
}

@Test
func defaultModeMatchesTokenModeOutput() {
    let original = "Add a diff"
    let updated = "Added a diff"

    let implicitDefault = TextDiffEngine.diff(original: original, updated: updated)
    let explicitToken = TextDiffEngine.diff(original: original, updated: updated, mode: .token)

    #expect(implicitDefault == explicitToken)
}

@Test
func characterModeRefinesWordSuffixInsertion() {
    let segments = TextDiffEngine.diff(original: "Add", updated: "Added", mode: .character)

    #expect(segments.contains { $0.kind == .equal && $0.tokenKind == .word && $0.text == "Add" })
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .word && $0.text == "ed" })
    #expect(!segments.contains { $0.kind == .delete && $0.tokenKind == .word })
}

@Test
func characterModeRefinesWordMiddleSubstitution() {
    let segments = TextDiffEngine.diff(original: "cat", updated: "cut", mode: .character)

    #expect(segments.contains { $0.kind == .equal && $0.tokenKind == .word && $0.text == "c" })
    #expect(segments.contains { $0.kind == .delete && $0.tokenKind == .word && $0.text == "a" })
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .word && $0.text == "u" })
    #expect(segments.contains { $0.kind == .equal && $0.tokenKind == .word && $0.text == "t" })
}

@Test
func characterModeKeepsNoCommonWordAsDeletesAndInserts() {
    let segments = TextDiffEngine.diff(original: "brown", updated: "sky", mode: .character)

    #expect(segments.contains { $0.kind == .delete && $0.tokenKind == .word })
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .word })
    #expect(!segments.contains { $0.kind == .equal && $0.tokenKind == .word })
}

@Test
func characterModeDoesNotRefinePunctuation() {
    let segments = TextDiffEngine.diff(original: "dog.", updated: "dog!", mode: .character)

    #expect(segments.contains { $0.kind == .equal && $0.tokenKind == .word && $0.text == "dog" })
    #expect(segments.contains { $0.kind == .delete && $0.tokenKind == .punctuation && $0.text == "." })
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .punctuation && $0.text == "!" })
}

@Test
func characterModePreservesWhitespaceBehavior() {
    let updated = "Hello world\n"
    let segments = TextDiffEngine.diff(original: "Hello   world", updated: updated, mode: .character)

    #expect(joinedText(segments) == updated)
    #expect(segments.filter { $0.tokenKind == .whitespace }.allSatisfy { $0.kind == .equal })
}

@Test
func characterModeHandlesComposedCharactersSafely() {
    let segments = TextDiffEngine.diff(original: "naïve", updated: "naïves", mode: .character)

    #expect(segments.contains { $0.kind == .equal && $0.tokenKind == .word && $0.text == "naïve" })
    #expect(segments.contains { $0.kind == .insert && $0.tokenKind == .word && $0.text == "s" })
}

@Test
func characterModeIsDeterministicForRepeatedCharacterTieCases() {
    let first = TextDiffEngine.diff(original: "aaaa", updated: "aa", mode: .character)
    let second = TextDiffEngine.diff(original: "aaaa", updated: "aa", mode: .character)

    #expect(first == second)
}

@Test
func resultSegmentsMatchDiffOutputInTokenMode() {
    let result = TextDiffEngine.result(original: "old value", updated: "new value", mode: .token)
    let segments = TextDiffEngine.diff(original: "old value", updated: "new value", mode: .token)

    #expect(result.segments == segments)
}

@Test
func resultSegmentsMatchDiffOutputInCharacterMode() {
    let result = TextDiffEngine.result(original: "Add", updated: "Added", mode: .character)
    let segments = TextDiffEngine.diff(original: "Add", updated: "Added", mode: .character)

    #expect(result.segments == segments)
}

@Test
func resultProducesOrderedChangeRecordsForReplacement() {
    let result = TextDiffEngine.result(original: "old value", updated: "new value", mode: .token)

    #expect(result.changes == [
        TextDiffChange(
            kind: .delete,
            tokenKind: .word,
            text: "old",
            originalOffset: 0,
            originalLength: 3,
            updatedOffset: 0,
            updatedLength: 0
        ),
        TextDiffChange(
            kind: .insert,
            tokenKind: .word,
            text: "new",
            originalOffset: 3,
            originalLength: 0,
            updatedOffset: 0,
            updatedLength: 3
        )
    ])
}

@Test
func resultSummaryCountsChangeRecordsAndCharacters() {
    let result = TextDiffEngine.result(original: "old value", updated: "new value", mode: .token)

    #expect(result.summary == TextDiffSummary(
        changeRecordInsertions: 1,
        changeRecordDeletions: 1,
        insertedCharacters: 3,
        deletedCharacters: 3
    ))
}

@Test
func resultSummaryIsModeSpecific() {
    let token = TextDiffEngine.result(original: "Add", updated: "Added", mode: .token)
    let character = TextDiffEngine.result(original: "Add", updated: "Added", mode: .character)

    #expect(token.summary == TextDiffSummary(
        changeRecordInsertions: 1,
        changeRecordDeletions: 1,
        insertedCharacters: 5,
        deletedCharacters: 3
    ))
    #expect(character.summary == TextDiffSummary(
        changeRecordInsertions: 1,
        changeRecordDeletions: 0,
        insertedCharacters: 2,
        deletedCharacters: 0
    ))
}

@Test
func fullInsertionProducesAnchoredInsertRecord() {
    let result = TextDiffEngine.result(original: "", updated: "Hello", mode: .token)

    #expect(result.changes == [
        TextDiffChange(
            kind: .insert,
            tokenKind: .word,
            text: "Hello",
            originalOffset: 0,
            originalLength: 0,
            updatedOffset: 0,
            updatedLength: 5
        )
    ])
}

@Test
func fullDeletionProducesAnchoredDeleteRecord() {
    let result = TextDiffEngine.result(original: "Hello", updated: "", mode: .token)

    #expect(result.changes == [
        TextDiffChange(
            kind: .delete,
            tokenKind: .word,
            text: "Hello",
            originalOffset: 0,
            originalLength: 5,
            updatedOffset: 0,
            updatedLength: 0
        )
    ])
}

@Test
func whitespaceOnlyLayoutChangesProduceNoChangeRecords() {
    let result = TextDiffEngine.result(original: "Hello   world", updated: "Hello world\n", mode: .token)

    #expect(result.changes.isEmpty)
    #expect(result.summary == TextDiffSummary(
        changeRecordInsertions: 0,
        changeRecordDeletions: 0,
        insertedCharacters: 0,
        deletedCharacters: 0
    ))
}

@Test
func insertOffsetsUseUtf16AnchorsForEmoji() throws {
    let result = TextDiffEngine.result(original: "a", updated: "a🌍", mode: .token)
    let change = try #require(result.changes.first)

    #expect(change.kind == .insert)
    #expect(change.originalOffset == 1)
    #expect(change.originalLength == 0)
    #expect(change.updatedOffset == 1)
    #expect(change.updatedLength == 2)
}

private func joinedText(_ segments: [DiffSegment]) -> String {
    segments.map(\.text).joined()
}
