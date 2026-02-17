import AppKit
import SnapshotTesting
import Testing
import TextDiff

@Suite(.snapshots(record: .missing))
@MainActor
struct NSTextDiffSnapshotTests {
    @Test
    func token_basic_replacement() {
        assertNSTextDiffSnapshot(
            original: "Apply old value in this sentence.",
            updated: "Apply new value in this sentence.",
            mode: .token,
            size: CGSize(width: 500, height: 120)
        )
    }

    @Test
    func character_suffix_refinement() {
        assertNSTextDiffSnapshot(
            original: "Add a diff",
            updated: "Added a diff",
            mode: .character,
            size: CGSize(width: 320, height: 110)
        )
    }

    @Test
    func punctuation_replacement() {
        assertNSTextDiffSnapshot(
            original: "Wait!",
            updated: "Wait.",
            mode: .token,
            size: CGSize(width: 320, height: 100)
        )
    }

    @Test
    func multiline_insertion_wrap() {
        assertNSTextDiffSnapshot(
            original: "line1\nline2",
            updated: "line1\nlineX\nline2",
            mode: .token,
            size: CGSize(width: 300, height: 150)
        )
    }

    @Test
    func custom_style_spacing_strikethrough() {
        var style = TextDiffStyle.default
        style.deletionStrikethrough = true
        style.interChipSpacing = 1

        assertNSTextDiffSnapshot(
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
