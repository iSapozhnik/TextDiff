import CoreGraphics
import Foundation

struct IndexedSegment {
    let segmentIndex: Int
    let segment: DiffSegment
    let originalCursor: Int
    let updatedCursor: Int
    let originalRange: NSRange
    let updatedRange: NSRange
}

enum DiffRevertCandidateKind: Equatable {
    case singleInsertion
    case singleDeletion
    case pairedReplacement
}

struct DiffRevertCandidate: Equatable {
    let id: Int
    let kind: DiffRevertCandidateKind
    let tokenKind: DiffTokenKind
    let segmentIndices: [Int]
    let updatedRange: NSRange
    let replacementText: String
    let originalTextFragment: String?
    let updatedTextFragment: String?
}

struct DiffRevertInteractionContext {
    let candidatesByID: [Int: DiffRevertCandidate]
    let runIndicesByActionID: [Int: [Int]]
    let chipRectsByActionID: [Int: [CGRect]]
    let unionChipRectByActionID: [Int: CGRect]
}

enum DiffRevertActionResolver {
    static func indexedSegments(
        from segments: [DiffSegment],
        original: String,
        updated: String
    ) -> [IndexedSegment] {
        var output: [IndexedSegment] = []
        output.reserveCapacity(segments.count)

        let originalNSString = original as NSString
        let updatedNSString = updated as NSString
        var originalCursor = 0
        var updatedCursor = 0

        for (index, segment) in segments.enumerated() {
            let textLength = segment.text.utf16.count
            let originalRange: NSRange
            let updatedRange: NSRange

            switch segment.kind {
            case .equal:
                originalRange = NSRange(location: originalCursor, length: textLength)
                updatedRange = NSRange(location: updatedCursor, length: textLength)
                if textMatches(segment.text, source: originalNSString, at: originalCursor) {
                    originalCursor += textLength
                }
                if textMatches(segment.text, source: updatedNSString, at: updatedCursor) {
                    updatedCursor += textLength
                }
            case .delete:
                originalRange = NSRange(location: originalCursor, length: textLength)
                updatedRange = NSRange(location: updatedCursor, length: 0)
                originalCursor += textLength
            case .insert:
                originalRange = NSRange(location: originalCursor, length: 0)
                updatedRange = NSRange(location: updatedCursor, length: textLength)
                updatedCursor += textLength
            }

            output.append(
                IndexedSegment(
                    segmentIndex: index,
                    segment: segment,
                    originalCursor: originalRange.location,
                    updatedCursor: updatedRange.location,
                    originalRange: originalRange,
                    updatedRange: updatedRange
                )
            )
        }

        return output
    }

    static func candidates(
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

    static func candidates(
        from segments: [DiffSegment],
        mode: TextDiffComparisonMode,
        original: String,
        updated: String
    ) -> [DiffRevertCandidate] {
        guard mode == .token else {
            return []
        }

        let indexed = indexedSegments(from: segments, original: original, updated: updated)
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
                   isCurrentLexical,
                   isLexicalChange(next.segment) {
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
                            updatedRange: NSRange(location: current.updatedCursor, length: 0),
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

    static func interactionContext(
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

    static func action(
        from candidate: DiffRevertCandidate,
        updated: String
    ) -> TextDiffRevertAction? {
        let nsUpdated = updated as NSString
        var updatedRange = candidate.updatedRange
        if candidate.kind == .singleDeletion, updatedRange.location > nsUpdated.length {
            updatedRange.location = nsUpdated.length
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

    private static func isLexicalChange(_ segment: DiffSegment) -> Bool {
        segment.tokenKind != .whitespace && segment.kind != .equal
    }

    private static func textMatches(_ text: String, source: NSString, at location: Int) -> Bool {
        let length = text.utf16.count
        guard location >= 0, location + length <= source.length else {
            return false
        }
        return source.substring(with: NSRange(location: location, length: length)) == text
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

        let beforeIsWordLike: Bool
        if insertionLocation > 0 {
            let previous = updated.substring(with: NSRange(location: insertionLocation - 1, length: 1))
            beforeIsWordLike = isWordLike(previous)
        } else {
            beforeIsWordLike = false
        }

        let afterIsWordLike: Bool
        if insertionLocation < updated.length {
            let next = updated.substring(with: NSRange(location: insertionLocation, length: 1))
            afterIsWordLike = isWordLike(next)
        } else {
            afterIsWordLike = false
        }

        var output = replacement
        if beforeIsWordLike && !hasLeadingWhitespace {
            output = " " + output
        }
        if afterIsWordLike && !hasTrailingWhitespace {
            output += " "
        }
        return output
    }

    private static func isWordLike(_ scalarString: String) -> Bool {
        scalarString.rangeOfCharacter(from: .alphanumerics) != nil
    }
}
