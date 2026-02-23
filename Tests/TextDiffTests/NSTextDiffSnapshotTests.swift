import AppKit
import SnapshotTesting
import TextDiff
import XCTest

final class NSTextDiffSnapshotTests: XCTestCase {
    override func invokeTest() {
        withSnapshotTesting(record: .missing) {
            super.invokeTest()
        }
    }

    @MainActor
    func testTokenBasicReplacement() {
        assertNSTextDiffSnapshot(
            original: "Apply old value in this sentence.",
            updated: "Apply new value in this sentence.",
            mode: .token,
            size: CGSize(width: 500, height: 120),
            testName: "token_basic_replacement()"
        )
    }

    @MainActor
    func testCharacterSuffixRefinement() {
        assertNSTextDiffSnapshot(
            original: "Add a diff",
            updated: "Added a diff",
            mode: .character,
            size: CGSize(width: 320, height: 110),
            testName: "character_suffix_refinement()"
        )
    }

    @MainActor
    func testPunctuationReplacement() {
        assertNSTextDiffSnapshot(
            original: "Wait!",
            updated: "Wait.",
            mode: .token,
            size: CGSize(width: 320, height: 100),
            testName: "punctuation_replacement()"
        )
    }

    @MainActor
    func testMultilineInsertionWrap() {
        assertNSTextDiffSnapshot(
            original: "line1\nline2",
            updated: "line1\nlineX\nline2",
            mode: .token,
            size: CGSize(width: 300, height: 150),
            testName: "multiline_insertion_wrap()"
        )
    }

    @MainActor
    func testCustomStyleSpacingStrikethrough() {
        var style = TextDiffStyle.default
        style.removalsStyle.strikethrough = true
        style.interChipSpacing = 1

        assertNSTextDiffSnapshot(
            original: sampleOriginalSentence,
            updated: sampleUpdatedSentence,
            mode: .character,
            style: style,
            size: CGSize(width: 300, height: 180),
            testName: "custom_style_spacing_strikethrough()"
        )
    }

    private let sampleOriginalSentence = "A quick brown fox jumps over a lazy dog."
    private let sampleUpdatedSentence = "A quick fox hops over the lazy dog!"
}
