import AppKit
import SnapshotTesting
import TextDiff
import XCTest

final class TextDiffSnapshotTests: XCTestCase {
    override func invokeTest() {
        withSnapshotTesting(record: .missing) {
            super.invokeTest()
        }
    }

    @MainActor
    func testTokenBasicReplacement() {
        assertTextDiffSnapshot(
            original: "Apply old value in this sentence.",
            updated: "Apply new value in this sentence.",
            mode: .token,
            size: CGSize(width: 500, height: 120),
            testName: "token_basic_replacement()"
        )
    }

    @MainActor
    func testCharacterSuffixRefinement() {
        assertTextDiffSnapshot(
            original: "Add a diff",
            updated: "Added a diff",
            mode: .character,
            size: CGSize(width: 320, height: 110),
            testName: "character_suffix_refinement()"
        )
    }

    @MainActor
    func testPunctuationReplacement() {
        assertTextDiffSnapshot(
            original: "Wait!",
            updated: "Wait.",
            mode: .token,
            size: CGSize(width: 320, height: 100),
            testName: "punctuation_replacement()"
        )
    }

    @MainActor
    func testWhitespaceOnlyLayoutChange() {
        assertTextDiffSnapshot(
            original: "Hello   world",
            updated: "Hello world\n",
            mode: .token,
            size: CGSize(width: 340, height: 110),
            testName: "whitespace_only_layout_change()"
        )
    }

    @MainActor
    func testMultilineInsertionWrap() {
        assertTextDiffSnapshot(
            original: "line1\nline2",
            updated: "line1\nlineX\nline2",
            mode: .token,
            size: CGSize(width: 300, height: 150),
            testName: "multiline_insertion_wrap()"
        )
    }

    @MainActor
    func testNarrowWidthWrapping() {
        assertTextDiffSnapshot(
            original: sampleOriginalSentence,
            updated: sampleUpdatedSentence,
            mode: .token,
            size: CGSize(width: 220, height: 180),
            testName: "narrow_width_wrapping()"
        )
    }

    @MainActor
    func testCustomStyleSpacingStrikethrough() {
        var style = TextDiffStyle.default
        style.removalsStyle.strikethrough = true
        style.interChipSpacing = 1

        assertTextDiffSnapshot(
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
