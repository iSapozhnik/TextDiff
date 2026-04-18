import AppKit
import Testing
import TextDiffCore
@testable import TextDiffMacOSUI

@Test
func defaultStyleInterChipSpacingMatchesCurrentDefault() {
    #expect(TextDiffStyle.default.interChipSpacing == 0)
}

@Test
func defaultGroupStrokeStyleIsSolid() {
    #expect(TextDiffStyle.default.groupStrokeStyle == .solid)
}

@Test
func textDiffStyleDefaultUsesDefaultAdditionAndRemovalStyles() {
    let style = TextDiffStyle.default
    expectColorEqual(style.additionsStyle.fillColor, TextDiffChangeStyle.defaultAddition.fillColor)
    expectColorEqual(style.additionsStyle.strokeColor, TextDiffChangeStyle.defaultAddition.strokeColor)
    expectColorEqual(style.removalsStyle.fillColor, TextDiffChangeStyle.defaultRemoval.fillColor)
    expectColorEqual(style.removalsStyle.strokeColor, TextDiffChangeStyle.defaultRemoval.strokeColor)
}

@Test
func textDiffStyleProtocolInitConvertsCustomConformers() {
    let additions = TestStyling(
        fillColor: .systemTeal,
        strokeColor: .systemCyan,
        textColorOverride: .black,
        strikethrough: false
    )
    let removals = TestStyling(
        fillColor: .systemOrange,
        strokeColor: .systemBrown,
        textColorOverride: .white,
        strikethrough: true
    )

    let style = TextDiffStyle(
        additionsStyle: additions,
        removalsStyle: removals,
        groupStrokeStyle: .dashed
    )

    expectColorEqual(style.additionsStyle.fillColor, additions.fillColor)
    expectColorEqual(style.additionsStyle.strokeColor, additions.strokeColor)
    expectColorEqual(style.additionsStyle.textColorOverride ?? .clear, additions.textColorOverride ?? .clear)
    #expect(style.additionsStyle.strikethrough == additions.strikethrough)

    expectColorEqual(style.removalsStyle.fillColor, removals.fillColor)
    expectColorEqual(style.removalsStyle.strokeColor, removals.strokeColor)
    expectColorEqual(style.removalsStyle.textColorOverride ?? .clear, removals.textColorOverride ?? .clear)
    #expect(style.removalsStyle.strikethrough == removals.strikethrough)
    #expect(style.groupStrokeStyle == .dashed)
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
func layouterRendersDeletedWhitespaceAsChipWhenReplacedByPunctuation() throws {
    let style = TextDiffStyle.default
    let layout = DiffTokenLayouter.layout(
        segments: [
            DiffSegment(kind: .equal, tokenKind: .word, text: "in"),
            DiffSegment(kind: .delete, tokenKind: .whitespace, text: " "),
            DiffSegment(kind: .insert, tokenKind: .punctuation, text: "-"),
            DiffSegment(kind: .equal, tokenKind: .word, text: "app")
        ],
        style: style,
        availableWidth: 500,
        contentInsets: zeroInsets
    )

    let deletedWhitespaceRun = layout.runs.first {
        $0.segment.kind == .delete && $0.segment.tokenKind == .whitespace
    }
    let insertedHyphenRun = layout.runs.first {
        $0.segment.kind == .insert && $0.segment.tokenKind == .punctuation && $0.segment.text == "-"
    }

    let deletedWhitespaceChip = try #require(deletedWhitespaceRun?.chipRect)
    let insertedHyphenChip = try #require(insertedHyphenRun?.chipRect)
    #expect(deletedWhitespaceChip.width > 0)
    #expect(insertedHyphenChip.width > 0)
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
func layouterPreventsInsertedTokenClipWithProportionalSystemFont() throws {
    var style = TextDiffStyle.default
    style.font = .systemFont(ofSize: 13)

    let layout = DiffTokenLayouter.layout(
        segments: [
            DiffSegment(kind: .delete, tokenKind: .word, text: "just"),
            DiffSegment(kind: .insert, tokenKind: .word, text: "simply")
        ],
        style: style,
        availableWidth: 500,
        contentInsets: zeroInsets
    )

    let insertedRunCandidate = layout.runs.first(where: {
        $0.segment.kind == .insert && $0.segment.tokenKind == .word && $0.segment.text == "simply"
    })
    let insertedRun = try #require(insertedRunCandidate)
    let insertedChip = try #require(insertedRun.chipRect)
    let standaloneWidth = ("simply" as NSString).size(withAttributes: [.font: style.font]).width

    #expect(insertedRun.textRect.width >= standaloneWidth - 0.0001)
    #expect(insertedChip.maxX >= insertedRun.textRect.maxX - 0.0001)
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
func layouterUsesRemovalStrikethroughFromRemovalStyle() throws {
    var style = TextDiffStyle.default
    style.removalsStyle.strikethrough = true

    let layout = DiffTokenLayouter.layout(
        segments: [DiffSegment(kind: .delete, tokenKind: .word, text: "old")],
        style: style,
        availableWidth: 500,
        contentInsets: zeroInsets
    )

    let run = try #require(layout.runs.first)
    let value = run.attributedText.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
    #expect(value == NSUnderlineStyle.single.rawValue)
}

@Test
func verticalInsetIsNonNegativeAndMonotonic() {
    var base = TextDiffStyle.default
    base.chipInsets = NSEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
    let baseInset = DiffTextLayoutMetrics.verticalTextInset(for: base)
    #expect(baseInset >= 0)

    var largerTop = base
    largerTop.chipInsets = NSEdgeInsets(top: 6, left: 2, bottom: 0, right: 2)
    let largerTopInset = DiffTextLayoutMetrics.verticalTextInset(for: largerTop)
    #expect(largerTopInset >= baseInset)

    var largerBottom = base
    largerBottom.chipInsets = NSEdgeInsets(top: 0, left: 2, bottom: 7, right: 2)
    let largerBottomInset = DiffTextLayoutMetrics.verticalTextInset(for: largerBottom)
    #expect(largerBottomInset >= baseInset)
}

@Test
func lineHeightUsesConfigurableLineSpacing() {
    var compact = TextDiffStyle.default
    compact.lineSpacing = 0

    var roomy = TextDiffStyle.default
    roomy.lineSpacing = 6

    let compactHeight = DiffTextLayoutMetrics.lineHeight(for: compact)
    let roomyHeight = DiffTextLayoutMetrics.lineHeight(for: roomy)
    #expect(roomyHeight - compactHeight >= 6 - 0.0001)
}

private func expectColorEqual(_ lhs: NSColor, _ rhs: NSColor, tolerance: CGFloat = 0.0001) {
    let left = rgba(lhs)
    let right = rgba(rhs)
    #expect(abs(left.0 - right.0) <= tolerance)
    #expect(abs(left.1 - right.1) <= tolerance)
    #expect(abs(left.2 - right.2) <= tolerance)
    #expect(abs(left.3 - right.3) <= tolerance)
}

private func rgba(_ color: NSColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    let rgb = color.usingColorSpace(.deviceRGB) ?? color
    return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent)
}

private struct TestStyling: TextDiffStyling {
    let fillColor: NSColor
    let strokeColor: NSColor
    let textColorOverride: NSColor?
    let strikethrough: Bool
}

private let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
