import AppKit
import SnapshotTesting
import Testing
import TextDiff

@Suite(.snapshots(record: .missing))
@MainActor
struct TextDiffSnapshotTests {
    @Test
    func token_basic_replacement() {
        assertTextDiffSnapshot(
            original: "Apply old value in this sentence.",
            updated: "Apply new value in this sentence.",
            mode: .token,
            size: CGSize(width: 500, height: 120)
        )
    }

    @Test
    func character_suffix_refinement() {
        assertTextDiffSnapshot(
            original: "Add a diff",
            updated: "Added a diff",
            mode: .character,
            size: CGSize(width: 320, height: 110)
        )
    }

    @Test
    func punctuation_replacement() {
        assertTextDiffSnapshot(
            original: "Wait!",
            updated: "Wait.",
            mode: .token,
            size: CGSize(width: 320, height: 100)
        )
    }

    @Test
    func whitespace_only_layout_change() {
        assertTextDiffSnapshot(
            original: "Hello   world",
            updated: "Hello world\n",
            mode: .token,
            size: CGSize(width: 340, height: 110)
        )
    }

    @Test
    func multiline_insertion_wrap() {
        assertTextDiffSnapshot(
            original: "line1\nline2",
            updated: "line1\nlineX\nline2",
            mode: .token,
            size: CGSize(width: 300, height: 150)
        )
    }

    @Test
    func narrow_width_wrapping() {
        assertTextDiffSnapshot(
            original: sampleOriginalSentence,
            updated: sampleUpdatedSentence,
            mode: .token,
            size: CGSize(width: 220, height: 180)
        )
    }

    @Test
    func custom_style_spacing_strikethrough() {
        var style = TextDiffStyle.default
        style.deletionStrikethrough = true
        style.interChipSpacing = 1

        assertTextDiffSnapshot(
            original: sampleOriginalSentence,
            updated: sampleUpdatedSentence,
            mode: .character,
            style: style,
            size: CGSize(width: 300, height: 180)
        )
    }

    private let sampleOriginalSentence = "A quick brown fox jumps over a lazy dog."
    private let sampleUpdatedSentence = "A quick fox hops over the lazy dog!"
}
