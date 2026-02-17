import AppKit
import Testing
@testable import TextDiff

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
func defaultStyleInterChipSpacingMatchesCurrentDefault() {
    #expect(TextDiffStyle.default.interChipSpacing == 0)
}

@Test
func layouterEnforcesGapForAdjacentChangedLexicalRuns() {
    var style = TextDiffStyle.default
    style.interChipSpacing = 4

    let layout = DiffTokenLayouter.layout(
        segments: [
            DiffSegment(kind: .delete, tokenKind: .word, text: "old"),
            DiffSegment(kind: .insert, tokenKind: .word, text: "new")
        ],
        style: style,
        availableWidth: 500,
        contentInsets: zeroInsets
    )

    let chips = layout.runs.compactMap { $0.chipRect }
    #expect(chips.count == 2)
    #expect(chips[1].minX - chips[0].maxX >= 4 - 0.0001)
}

@Test
func layouterPreservesMinimumHorizontalPaddingFloor() throws {
    var style = TextDiffStyle.default
    style.chipInsets = NSEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)

    let layout = DiffTokenLayouter.layout(
        segments: [DiffSegment(kind: .delete, tokenKind: .word, text: "token")],
        style: style,
        availableWidth: 500,
        contentInsets: zeroInsets
    )

    let run = try #require(layout.runs.first)
    let chipRect = try #require(run.chipRect)
    #expect(chipRect.minX <= run.textRect.minX - 3 + 0.0001)
    #expect(chipRect.maxX >= run.textRect.maxX + 3 - 0.0001)
}

@Test
func layouterAppliesGapForPunctuationAdjacency() {
    var style = TextDiffStyle.default
    style.interChipSpacing = 4

    let layout = DiffTokenLayouter.layout(
        segments: [
            DiffSegment(kind: .delete, tokenKind: .punctuation, text: "!"),
            DiffSegment(kind: .insert, tokenKind: .punctuation, text: ".")
        ],
        style: style,
        availableWidth: 500,
        contentInsets: zeroInsets
    )

    let chips = layout.runs.compactMap { $0.chipRect }
    #expect(chips.count == 2)
    #expect(chips[1].minX - chips[0].maxX >= 4 - 0.0001)
}

@Test
func layouterDoesNotInjectAdjacencyGapAcrossUnchangedWhitespace() throws {
    let style = TextDiffStyle.default
    let layout = DiffTokenLayouter.layout(
        segments: [
            DiffSegment(kind: .delete, tokenKind: .word, text: "old"),
            DiffSegment(kind: .equal, tokenKind: .whitespace, text: " "),
            DiffSegment(kind: .insert, tokenKind: .word, text: "new")
        ],
        style: style,
        availableWidth: 500,
        contentInsets: zeroInsets
    )

    let deleteRun = layout.runs[0]
    let whitespaceRun = layout.runs[1]
    let insertRun = layout.runs[2]

    let deleteChip = try #require(deleteRun.chipRect)
    let insertChip = try #require(insertRun.chipRect)
    let actualGap = insertChip.minX - deleteChip.maxX
    #expect(abs(actualGap - whitespaceRun.textRect.width) < 0.0001)
}

@Test
func layouterWrapsByTokenAndRespectsExplicitNewlines() {
    let layout = DiffTokenLayouter.layout(
        segments: [
            DiffSegment(kind: .equal, tokenKind: .word, text: "alpha"),
            DiffSegment(kind: .equal, tokenKind: .whitespace, text: " "),
            DiffSegment(kind: .insert, tokenKind: .word, text: "beta"),
            DiffSegment(kind: .equal, tokenKind: .whitespace, text: "\n"),
            DiffSegment(kind: .equal, tokenKind: .word, text: "gamma")
        ],
        style: .default,
        availableWidth: 45,
        contentInsets: zeroInsets
    )

    #expect(layout.runs.contains { $0.segment.text == "alpha" })
    #expect(layout.runs.contains { $0.segment.text == "beta" })
    #expect(layout.runs.contains { $0.segment.text == "gamma" })
    #expect(layout.runs.allSatisfy { !$0.segment.text.contains("\n") })

    let linePositions = Set(layout.runs.map { Int($0.textRect.minY.rounded()) })
    #expect(linePositions.count >= 2)
}

@Test
func verticalInsetScalesWithChipInsets() {
    #expect(DiffTextLayoutMetrics.verticalTextInset(for: .default) == 3)

    var style = TextDiffStyle.default
    style.chipInsets = NSEdgeInsets(top: 6, left: 2, bottom: 1, right: 2)
    #expect(DiffTextLayoutMetrics.verticalTextInset(for: style) == 8)
}

private func joinedText(_ segments: [DiffSegment]) -> String {
    segments.map(\.text).joined()
}

private let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
