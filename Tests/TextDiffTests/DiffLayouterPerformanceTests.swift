import AppKit
import XCTest
@testable import TextDiff

// swift test --filter DiffLayouterPerformanceTests 2>&1 | xcsift

final class DiffLayouterPerformanceTests: XCTestCase {
    func testLayoutPerformance200Words() {
        runLayoutPerformanceTest(wordCount: 200)
    }

    func testLayoutPerformance500Words() {
        runLayoutPerformanceTest(wordCount: 500)
    }

    func testLayoutPerformance1000Words() {
        runLayoutPerformanceTest(wordCount: 1000)
    }

    func testLayoutPerformance500WordsWithRevertInteractions() {
        runLayoutWithRevertInteractionsPerformanceTest(wordCount: 500)
    }

    private func runLayoutPerformanceTest(wordCount: Int) {
        let style = TextDiffStyle.default
        let verticalInset = DiffTextLayoutMetrics.verticalTextInset(for: style)
        let contentInsets = NSEdgeInsets(top: verticalInset, left: 0, bottom: verticalInset, right: 0)
        let availableWidth: CGFloat = 520

        let original = Self.largeText(wordCount: wordCount)
        let updated = Self.replacingLastWord(in: original)
        let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .character)

        measure(metrics: [XCTClockMetric()]) {
            let layout = DiffTokenLayouter.layout(
                segments: segments,
                style: style,
                availableWidth: availableWidth,
                contentInsets: contentInsets
            )
            XCTAssertFalse(layout.runs.isEmpty)
        }
    }

    private func runLayoutWithRevertInteractionsPerformanceTest(wordCount: Int) {
        let style = TextDiffStyle.default
        let verticalInset = DiffTextLayoutMetrics.verticalTextInset(for: style)
        let contentInsets = NSEdgeInsets(top: verticalInset, left: 0, bottom: verticalInset, right: 0)
        let availableWidth: CGFloat = 520

        let original = Self.largeText(wordCount: wordCount)
        let updated = Self.replacingLastWord(in: original)
        let segments = TextDiffEngine.diff(original: original, updated: updated, mode: .token)

        measure(metrics: [XCTClockMetric()]) {
            let layout = DiffTokenLayouter.layout(
                segments: segments,
                style: style,
                availableWidth: availableWidth,
                contentInsets: contentInsets
            )
            let context = DiffRevertActionResolver.interactionContext(
                segments: segments,
                runs: layout.runs,
                mode: .token
            )
            XCTAssertFalse(layout.runs.isEmpty)
            XCTAssertNotNil(context)
        }
    }

    private static func largeText(wordCount: Int) -> String {
        let vocabulary = [
            "alpha", "beta", "gamma", "delta", "epsilon", "theta", "lambda", "sigma",
            "swift", "layout", "render", "token", "word", "segment", "measure", "width"
        ]
        var words: [String] = []
        words.reserveCapacity(wordCount)

        for index in 0..<wordCount {
            words.append(vocabulary[index % vocabulary.count])
        }

        return words.joined(separator: " ")
    }

    private static func replacingLastWord(in text: String) -> String {
        guard let lastSpace = text.lastIndex(of: " ") else {
            return "changed"
        }
        return String(text[..<lastSpace]) + " changed"
    }
}
