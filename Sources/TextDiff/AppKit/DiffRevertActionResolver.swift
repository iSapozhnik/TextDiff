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
    static func indexedSegments(from segments: [DiffSegment]) -> [IndexedSegment] {
        var output: [IndexedSegment] = []
        output.reserveCapacity(segments.count)

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
                originalCursor += textLength
                updatedCursor += textLength
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
        guard mode == .token else {
            return []
        }

        let indexed = indexedSegments(from: segments)
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
        mode: TextDiffComparisonMode
    ) -> DiffRevertInteractionContext? {
        let candidates = candidates(from: segments, mode: mode)
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
        guard candidate.updatedRange.location >= 0 else {
            return nil
        }
        guard NSMaxRange(candidate.updatedRange) <= nsUpdated.length else {
            return nil
        }

        let resultingUpdated = nsUpdated.replacingCharacters(
            in: candidate.updatedRange,
            with: candidate.replacementText
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
            updatedRange: candidate.updatedRange,
            replacementText: candidate.replacementText,
            originalTextFragment: candidate.originalTextFragment,
            updatedTextFragment: candidate.updatedTextFragment,
            resultingUpdated: resultingUpdated
        )
    }

    private static func isLexicalChange(_ segment: DiffSegment) -> Bool {
        segment.tokenKind != .whitespace && segment.kind != .equal
    }
}
