import CoreGraphics
import Foundation
import TextDiffCore

package enum DiffRevertCandidateKind: Equatable {
    case singleInsertion
    case singleDeletion
    case pairedReplacement
}

package struct DiffRevertCandidate: Equatable {
    package let id: Int
    package let kind: DiffRevertCandidateKind
    package let tokenKind: DiffTokenKind
    package let segmentIndices: [Int]
    package let updatedRange: NSRange
    package let replacementText: String
    package let originalTextFragment: String?
    package let updatedTextFragment: String?
}

package struct DiffRevertInteractionContext {
    package let candidatesByID: [Int: DiffRevertCandidate]
    package let runIndicesByActionID: [Int: [Int]]
    package let chipRectsByActionID: [Int: [CGRect]]
    package let unionChipRectByActionID: [Int: CGRect]

    package init(
        candidatesByID: [Int: DiffRevertCandidate],
        runIndicesByActionID: [Int: [Int]],
        chipRectsByActionID: [Int: [CGRect]],
        unionChipRectByActionID: [Int: CGRect]
    ) {
        self.candidatesByID = candidatesByID
        self.runIndicesByActionID = runIndicesByActionID
        self.chipRectsByActionID = chipRectsByActionID
        self.unionChipRectByActionID = unionChipRectByActionID
    }
}

package enum DiffRevertActionResolver {
    package static func candidates(
        from segments: [DiffSegment],
        mode: TextDiffComparisonMode
    ) -> [DiffRevertCandidate] {
        let original = segments
            .filter { $0.kind != .insert }
            .map(\.text)
            .joined()
        let updated = segments
            .filter { $0.kind != .delete }
            .map(\.text)
            .joined()
        return candidates(from: segments, mode: mode, original: original, updated: updated)
    }

    package static func candidates(
        from segments: [DiffSegment],
        mode: TextDiffComparisonMode,
        original: String,
        updated: String
    ) -> [DiffRevertCandidate] {
        guard mode == .token else {
            return []
        }

        let indexed = DiffSegmentIndexer.indexedSegments(from: segments, original: original, updated: updated)
        guard !indexed.isEmpty else {
            return []
        }

        var output: [DiffRevertCandidate] = []
        output.reserveCapacity(indexed.count)

        var candidateID = 0
        var index = 0
        while index < indexed.count {
            let current = indexed[index]
            let isCurrentLexical = isLexicalChange(current.segment)

            if index + 1 < indexed.count {
                let next = indexed[index + 1]
                if current.segment.kind == .delete,
                   next.segment.kind == .insert,
                   isReplacementPair(delete: current.segment, insert: next.segment) {
                    output.append(
                        DiffRevertCandidate(
                            id: candidateID,
                            kind: .pairedReplacement,
                            tokenKind: current.segment.tokenKind,
                            segmentIndices: [current.segmentIndex, next.segmentIndex],
                            updatedRange: next.updatedRange,
                            replacementText: current.segment.text,
                            originalTextFragment: current.segment.text,
                            updatedTextFragment: next.segment.text
                        )
                    )
                    candidateID += 1
                    index += 2
                    continue
                }
            }

            if isCurrentLexical {
                switch current.segment.kind {
                case .insert:
                    output.append(
                        DiffRevertCandidate(
                            id: candidateID,
                            kind: .singleInsertion,
                            tokenKind: current.segment.tokenKind,
                            segmentIndices: [current.segmentIndex],
                            updatedRange: current.updatedRange,
                            replacementText: "",
                            originalTextFragment: nil,
                            updatedTextFragment: current.segment.text
                        )
                    )
                    candidateID += 1
                case .delete:
                    output.append(
                        DiffRevertCandidate(
                            id: candidateID,
                            kind: .singleDeletion,
                            tokenKind: current.segment.tokenKind,
                            segmentIndices: [current.segmentIndex],
                            updatedRange: NSRange(location: current.updatedRange.location, length: 0),
                            replacementText: current.segment.text,
                            originalTextFragment: current.segment.text,
                            updatedTextFragment: nil
                        )
                    )
                    candidateID += 1
                case .equal:
                    break
                }
            }

            index += 1
        }

        return output
    }

    package static func interactionContext(
        segments: [DiffSegment],
        runs: [LaidOutRun],
        mode: TextDiffComparisonMode,
        original: String,
        updated: String
    ) -> DiffRevertInteractionContext? {
        let candidates = candidates(from: segments, mode: mode, original: original, updated: updated)
        guard !candidates.isEmpty else {
            return nil
        }

        var actionIDBySegmentIndex: [Int: Int] = [:]
        actionIDBySegmentIndex.reserveCapacity(candidates.count * 2)
        var candidatesByID: [Int: DiffRevertCandidate] = [:]
        candidatesByID.reserveCapacity(candidates.count)

        for candidate in candidates {
            candidatesByID[candidate.id] = candidate
            for segmentIndex in candidate.segmentIndices {
                actionIDBySegmentIndex[segmentIndex] = candidate.id
            }
        }

        var runIndicesByActionID: [Int: [Int]] = [:]
        var chipRectsByActionID: [Int: [CGRect]] = [:]
        var unionChipRectByActionID: [Int: CGRect] = [:]

        for (runIndex, run) in runs.enumerated() {
            guard let chipRect = run.chipRect else {
                continue
            }
            guard let actionID = actionIDBySegmentIndex[run.segmentIndex] else {
                continue
            }
            runIndicesByActionID[actionID, default: []].append(runIndex)
            chipRectsByActionID[actionID, default: []].append(chipRect)
            if let currentUnion = unionChipRectByActionID[actionID] {
                unionChipRectByActionID[actionID] = currentUnion.union(chipRect)
            } else {
                unionChipRectByActionID[actionID] = chipRect
            }
        }

        guard !runIndicesByActionID.isEmpty else {
            return nil
        }

        candidatesByID = candidatesByID.filter { runIndicesByActionID[$0.key] != nil }

        return DiffRevertInteractionContext(
            candidatesByID: candidatesByID,
            runIndicesByActionID: runIndicesByActionID,
            chipRectsByActionID: chipRectsByActionID,
            unionChipRectByActionID: unionChipRectByActionID
        )
    }

    package static func action(
        from candidate: DiffRevertCandidate,
        updated: String
    ) -> TextDiffRevertAction? {
        let nsUpdated = updated as NSString
        guard candidateUpdatedFragmentMatches(candidate, updated: nsUpdated) else {
            return nil
        }

        var updatedRange = candidate.updatedRange
        if candidate.kind == .singleDeletion, updatedRange.location > nsUpdated.length {
            updatedRange.location = nsUpdated.length
        }
        if candidate.kind == .singleInsertion, candidate.tokenKind == .word {
            updatedRange = adjustedStandaloneWordInsertionRemovalRange(
                updatedRange,
                updated: nsUpdated
            )
        }
        guard updatedRange.location >= 0 else {
            return nil
        }
        guard NSMaxRange(updatedRange) <= nsUpdated.length else {
            return nil
        }

        let replacementText: String
        if candidate.kind == .singleDeletion, candidate.tokenKind == .word {
            replacementText = adjustedStandaloneWordDeletionReplacement(
                candidate.replacementText,
                insertionLocation: updatedRange.location,
                updated: nsUpdated
            )
        } else {
            replacementText = candidate.replacementText
        }

        let resultingUpdated = nsUpdated.replacingCharacters(
            in: updatedRange,
            with: replacementText
        )
        let actionKind: TextDiffRevertActionKind
        switch candidate.kind {
        case .singleInsertion:
            actionKind = .singleInsertion
        case .singleDeletion:
            actionKind = .singleDeletion
        case .pairedReplacement:
            actionKind = .pairedReplacement
        }

        return TextDiffRevertAction(
            kind: actionKind,
            updatedRange: updatedRange,
            replacementText: replacementText,
            originalTextFragment: candidate.originalTextFragment,
            updatedTextFragment: candidate.updatedTextFragment,
            resultingUpdated: resultingUpdated
        )
    }

    private static func candidateUpdatedFragmentMatches(
        _ candidate: DiffRevertCandidate,
        updated: NSString
    ) -> Bool {
        guard let updatedTextFragment = candidate.updatedTextFragment else {
            return true
        }

        let range = candidate.updatedRange
        guard range.location >= 0, range.length >= 0 else {
            return false
        }
        guard NSMaxRange(range) <= updated.length else {
            return false
        }

        return updated.substring(with: range) == updatedTextFragment
    }

    private static func isLexicalChange(_ segment: DiffSegment) -> Bool {
        segment.tokenKind != .whitespace && segment.kind != .equal
    }

    private static func isReplacementPair(delete: DiffSegment, insert: DiffSegment) -> Bool {
        if isLexicalChange(delete), isLexicalChange(insert) {
            return true
        }

        // Treat deleted spacing replaced by punctuation as one reversible edit.
        if delete.tokenKind == .whitespace,
           insert.tokenKind == .punctuation {
            return true
        }

        return false
    }

    private static func adjustedStandaloneWordDeletionReplacement(
        _ replacement: String,
        insertionLocation: Int,
        updated: NSString
    ) -> String {
        guard !replacement.isEmpty else {
            return replacement
        }
        guard replacement.rangeOfCharacter(from: .alphanumerics) != nil else {
            return replacement
        }

        let hasLeadingWhitespace = replacement.unicodeScalars.first
            .map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false
        let hasTrailingWhitespace = replacement.unicodeScalars.last
            .map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false

        let updatedString = updated as String
        let beforeIsWordLike = characterBeforeUTF16Offset(insertionLocation, in: updatedString)
            .map(isWordLike) ?? false
        let afterIsWordLike = characterAtUTF16Offset(insertionLocation, in: updatedString)
            .map(isWordLike) ?? false

        var output = replacement
        if beforeIsWordLike && !hasLeadingWhitespace {
            output = " " + output
        }
        if afterIsWordLike && !hasTrailingWhitespace {
            output += " "
        }
        return output
    }

    private static func adjustedStandaloneWordInsertionRemovalRange(
        _ range: NSRange,
        updated: NSString
    ) -> NSRange {
        guard range.location >= 0, range.length >= 0 else {
            return range
        }
        guard NSMaxRange(range) <= updated.length else {
            return range
        }

        let updatedString = updated as String
        let hasLeadingWhitespace = characterBeforeUTF16Offset(range.location, in: updatedString)
            .map(isWhitespaceCharacter) ?? false
        let hasTrailingWhitespace = characterAtUTF16Offset(NSMaxRange(range), in: updatedString)
            .map(isWhitespaceCharacter) ?? false

        if hasLeadingWhitespace, hasTrailingWhitespace {
            return NSRange(location: range.location, length: range.length + 1)
        }

        if range.location == 0, hasTrailingWhitespace {
            return NSRange(location: range.location, length: range.length + 1)
        }

        if NSMaxRange(range) == updated.length, hasLeadingWhitespace {
            return NSRange(location: range.location - 1, length: range.length + 1)
        }

        return range
    }

    private static func isWhitespaceCharacter(_ scalarString: String) -> Bool {
        scalarString.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    private static func isWordLike(_ scalarString: String) -> Bool {
        scalarString.rangeOfCharacter(from: .alphanumerics) != nil
    }

    private static func characterBeforeUTF16Offset(_ offset: Int, in string: String) -> String? {
        guard offset > 0 else {
            return nil
        }
        let index = String.Index(utf16Offset: offset, in: string)
        guard index > string.startIndex else {
            return nil
        }
        return String(string[string.index(before: index)])
    }

    private static func characterAtUTF16Offset(_ offset: Int, in string: String) -> String? {
        guard offset >= 0 else {
            return nil
        }
        let index = String.Index(utf16Offset: offset, in: string)
        guard index < string.endIndex else {
            return nil
        }
        return String(string[index])
    }
}
