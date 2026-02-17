import Foundation
import NaturalLanguage

enum Tokenizer {
    struct Token: Sendable, Hashable {
        let kind: DiffTokenKind
        let text: String
    }

    static func tokenize(_ text: String) -> [Token] {
        guard !text.isEmpty else {
            return []
        }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        let fullRange = text.startIndex..<text.endIndex
        let wordRanges = tokenizer.tokens(for: fullRange)

        var tokens: [Token] = []
        var cursor = text.startIndex

        for wordRange in wordRanges {
            if cursor < wordRange.lowerBound {
                appendGapTokens(from: text[cursor..<wordRange.lowerBound], to: &tokens)
            }

            tokens.append(Token(kind: .word, text: String(text[wordRange])))
            cursor = wordRange.upperBound
        }

        if cursor < text.endIndex {
            appendGapTokens(from: text[cursor..<text.endIndex], to: &tokens)
        }

        return tokens
    }

    private static func appendGapTokens(from gap: Substring, to tokens: inout [Token]) {
        guard !gap.isEmpty else {
            return
        }

        var start = gap.startIndex
        var currentKind = tokenKind(for: gap[start])
        var index = gap.index(after: start)

        while index < gap.endIndex {
            let nextKind = tokenKind(for: gap[index])
            if nextKind != currentKind {
                tokens.append(Token(kind: currentKind, text: String(gap[start..<index])))
                start = index
                currentKind = nextKind
            }
            index = gap.index(after: index)
        }

        tokens.append(Token(kind: currentKind, text: String(gap[start..<gap.endIndex])))
    }

    private static func tokenKind(for character: Character) -> DiffTokenKind {
        character.isWhitespace ? .whitespace : .punctuation
    }
}
