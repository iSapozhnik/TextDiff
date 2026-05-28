import Foundation

package struct IndexedDiffSegment {
    package let segmentIndex: Int
    package let segment: DiffSegment
    package let originalRange: NSRange
    package let updatedRange: NSRange
}

package enum DiffSegmentIndexer {
    package static func indexedSegments(
        from segments: [DiffSegment],
        original: String,
        updated: String
    ) -> [IndexedDiffSegment] {
        var output: [IndexedDiffSegment] = []
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
                let originalMatches = textMatches(segment.text, source: originalNSString, at: originalCursor)
                let updatedMatches = textMatches(segment.text, source: updatedNSString, at: updatedCursor)
                #if !TESTING
                assert(
                    originalMatches,
                    "Equal segment text mismatch in original at \(originalCursor) for segment \(index): \(segment.text)"
                )
                assert(
                    updatedMatches,
                    "Equal segment text mismatch in updated at \(updatedCursor) for segment \(index): \(segment.text)"
                )
                #endif
                if originalMatches {
                    originalCursor += textLength
                }
                if updatedMatches {
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
                IndexedDiffSegment(
                    segmentIndex: index,
                    segment: segment,
                    originalRange: originalRange,
                    updatedRange: updatedRange
                )
            )
        }

        return output
    }

    private static func textMatches(_ text: String, source: NSString, at location: Int) -> Bool {
        let length = text.utf16.count
        guard location >= 0, location + length <= source.length else {
            return false
        }
        return source.substring(with: NSRange(location: location, length: length)) == text
    }
}
