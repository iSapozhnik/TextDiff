import Foundation

public enum TextDiffEngine {
    public static func diff(
        original: String,
        updated: String,
        mode: TextDiffComparisonMode = .token
    ) -> [DiffSegment] {
        let segments = tokenDiffSegments(original: original, updated: updated)
        switch mode {
        case .token:
            return segments
        case .character:
            return refineWordReplacementsByCharacter(segments: segments)
        }
    }

    private static func tokenDiffSegments(original: String, updated: String) -> [DiffSegment] {
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

    private static func refineWordReplacementsByCharacter(segments: [DiffSegment]) -> [DiffSegment] {
        guard !segments.isEmpty else {
            return []
        }

        var refined: [DiffSegment] = []
        refined.reserveCapacity(segments.count)

        var index = 0
        while index < segments.count {
            if index + 1 < segments.count,
               let replacement = refinedReplacementSegments(
                deleteSegment: segments[index],
                insertSegment: segments[index + 1]
               ) {
                refined.append(contentsOf: replacement)
                index += 2
                continue
            }

            refined.append(segments[index])
            index += 1
        }

        return mergeAdjacentSegments(refined)
    }

    private static func refinedReplacementSegments(
        deleteSegment: DiffSegment,
        insertSegment: DiffSegment
    ) -> [DiffSegment]? {
        guard deleteSegment.kind == .delete,
              insertSegment.kind == .insert,
              deleteSegment.tokenKind == .word,
              insertSegment.tokenKind == .word else {
            return nil
        }

        let original = deleteSegment.text.map { Tokenizer.Token(kind: .word, text: String($0)) }
        let updated = insertSegment.text.map { Tokenizer.Token(kind: .word, text: String($0)) }
        let operations = MyersDiff.diff(original: original, updated: updated)

        let segments = operations.map {
            DiffSegment(kind: $0.kind, tokenKind: .word, text: $0.token.text)
        }
        return mergeAdjacentSegments(segments)
    }

    private static func mergeAdjacentSegments(_ segments: [DiffSegment]) -> [DiffSegment] {
        guard !segments.isEmpty else {
            return []
        }

        var merged: [DiffSegment] = []
        merged.reserveCapacity(segments.count)

        for segment in segments where !segment.text.isEmpty {
            if let last = merged.last,
               last.kind == segment.kind,
               last.tokenKind == segment.tokenKind {
                merged[merged.count - 1] = DiffSegment(
                    kind: last.kind,
                    tokenKind: last.tokenKind,
                    text: last.text + segment.text
                )
            } else {
                merged.append(segment)
            }
        }

        return merged
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
