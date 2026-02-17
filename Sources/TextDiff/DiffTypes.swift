import Foundation

/// The lexical category assigned to a token in diff output.
public enum DiffTokenKind: Sendable {
    /// A word token produced by word tokenization.
    case word
    /// A punctuation token that is not treated as whitespace.
    case punctuation
    /// A whitespace token, including spaces, tabs, and newlines.
    case whitespace
}

/// The edit operation represented by a diff segment.
public enum DiffOperationKind: Sendable {
    /// A token present in both original and updated text.
    case equal
    /// A token removed from the original text.
    case delete
    /// A token added in the updated text.
    case insert
}

/// The granularity used to compute and refine text differences.
public enum TextDiffComparisonMode: Sendable {
    /// Compares text at token granularity.
    case token
    /// Refines adjacent word replacements at character granularity.
    case character
}

/// A contiguous run of text tagged with an edit operation and token kind.
public struct DiffSegment: Sendable, Equatable {
    /// The edit operation represented by this segment.
    public let kind: DiffOperationKind
    /// The token kind represented by this segment.
    public let tokenKind: DiffTokenKind
    /// The segment text for this operation.
    public let text: String

    /// Creates a diff segment with operation metadata and text content.
    ///
    /// - Parameters:
    ///   - kind: The edit operation represented by the segment.
    ///   - tokenKind: The lexical category of the segment text.
    ///   - text: The text content for the segment.
    public init(kind: DiffOperationKind, tokenKind: DiffTokenKind, text: String) {
        self.kind = kind
        self.tokenKind = tokenKind
        self.text = text
    }
}
