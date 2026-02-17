import Foundation

public enum TextDiffEngine {
    public static func diff(original: String, updated: String) -> [DiffSegment] {
        let originalTokens = Tokenizer.tokenize(original)
        let updatedTokens = Tokenizer.tokenize(updated)
        let operations = MyersDiff.diff(original: originalTokens, updated: updatedTokens)

        var segments: [DiffSegment] = []
        segments.reserveCapacity(operations.count)

        var index = 0
        while index < operations.count {
            let operation = operations[index]

            if operation.token.kind == .whitespace {
                let runStart = index
                var runEnd = index
                while runEnd < operations.count, operations[runEnd].token.kind == .whitespace {
                    runEnd += 1
                }

                let whitespaceRun = operations[runStart..<runEnd]
                let updatedWhitespace = whitespaceRun
                    .filter { $0.kind != .delete }
                    .map(\.token.text)
                    .joined()

                if !updatedWhitespace.isEmpty {
                    segments.append(
                        DiffSegment(kind: .equal, tokenKind: .whitespace, text: updatedWhitespace)
                    )
                } else if isAdjacentToDeletedLexicalToken(operations: operations, runStart: runStart, runEnd: runEnd) {
                    let deletedWhitespace = whitespaceRun.map(\.token.text).joined()
                    segments.append(
                        DiffSegment(kind: .equal, tokenKind: .whitespace, text: deletedWhitespace)
                    )
                }

                index = runEnd
                continue
            }

            segments.append(
                DiffSegment(
                    kind: operation.kind,
                    tokenKind: operation.token.kind,
                    text: operation.token.text
                )
            )
            index += 1
        }

        return segments
    }

    private static func isAdjacentToDeletedLexicalToken(
        operations: [MyersDiff.Operation],
        runStart: Int,
        runEnd: Int
    ) -> Bool {
        if let previousLexicalIndex = previousLexicalOperationIndex(in: operations, before: runStart),
           operations[previousLexicalIndex].kind == .delete {
            return true
        }

        if let nextLexicalIndex = nextLexicalOperationIndex(in: operations, after: runEnd),
           operations[nextLexicalIndex].kind == .delete {
            return true
        }

        return false
    }

    private static func previousLexicalOperationIndex(
        in operations: [MyersDiff.Operation],
        before index: Int
    ) -> Int? {
        guard index > 0 else {
            return nil
        }

        var probe = index - 1
        while probe >= 0 {
            if operations[probe].token.kind != .whitespace {
                return probe
            }
            probe -= 1
        }

        return nil
    }

    private static func nextLexicalOperationIndex(
        in operations: [MyersDiff.Operation],
        after index: Int
    ) -> Int? {
        guard index < operations.count else {
            return nil
        }

        var probe = index
        while probe < operations.count {
            if operations[probe].token.kind != .whitespace {
                return probe
            }
            probe += 1
        }

        return nil
    }
}
