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

/// The change variant represented by a user-initiated revert action.
public enum TextDiffRevertActionKind: Sendable, Equatable {
    /// Revert a standalone inserted segment by removing it from updated text.
    case singleInsertion
    /// Revert a standalone deleted segment by inserting it into updated text.
    case singleDeletion
    /// Revert an adjacent delete+insert replacement pair.
    case pairedReplacement
}

/// A revert intent payload describing how to edit updated text toward original text.
public struct TextDiffRevertAction: Sendable, Equatable {
    /// The semantic action kind that triggered this payload.
    public let kind: TextDiffRevertActionKind
    /// The UTF-16 range in pre-click updated text to replace.
    public let updatedRange: NSRange
    /// The text used to replace `updatedRange`.
    public let replacementText: String
    /// Optional source-side text fragment associated with this action.
    public let originalTextFragment: String?
    /// Optional updated-side text fragment associated with this action.
    public let updatedTextFragment: String?
    /// The resulting updated text after applying the replacement.
    public let resultingUpdated: String

    public init(
        kind: TextDiffRevertActionKind,
        updatedRange: NSRange,
        replacementText: String,
        originalTextFragment: String?,
        updatedTextFragment: String?,
        resultingUpdated: String
    ) {
        self.kind = kind
        self.updatedRange = updatedRange
        self.replacementText = replacementText
        self.originalTextFragment = originalTextFragment
        self.updatedTextFragment = updatedTextFragment
        self.resultingUpdated = resultingUpdated
    }
}
