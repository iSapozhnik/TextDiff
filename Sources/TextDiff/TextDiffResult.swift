import Foundation

/// The kind of non-equal change represented in a diff result.
public enum TextDiffChangeKind: Sendable, Equatable {
    /// Text inserted into the updated value.
    case insert
    /// Text removed from the original value.
    case delete
}

/// A persistable change record produced from a computed diff.
public struct TextDiffChange: Sendable, Equatable {
    /// The insert/delete kind of this change record.
    public let kind: TextDiffChangeKind
    /// The lexical category of the changed text.
    public let tokenKind: DiffTokenKind
    /// The inserted or deleted text for this record.
    public let text: String
    /// The UTF-16 anchor position in the original text for this change.
    public let originalOffset: Int
    /// The UTF-16 length in the original text affected by this change.
    public let originalLength: Int
    /// The UTF-16 anchor position in the updated text for this change.
    public let updatedOffset: Int
    /// The UTF-16 length in the updated text affected by this change.
    public let updatedLength: Int

    public init(
        kind: TextDiffChangeKind,
        tokenKind: DiffTokenKind,
        text: String,
        originalOffset: Int,
        originalLength: Int,
        updatedOffset: Int,
        updatedLength: Int
    ) {
        self.kind = kind
        self.tokenKind = tokenKind
        self.text = text
        self.originalOffset = originalOffset
        self.originalLength = originalLength
        self.updatedOffset = updatedOffset
        self.updatedLength = updatedLength
    }
}

/// Lightweight summary statistics derived from diff change records.
public struct TextDiffSummary: Sendable, Equatable {
    /// The number of insert change records.
    public let changeRecordInsertions: Int
    /// The number of delete change records.
    public let changeRecordDeletions: Int
    /// The number of visible characters inserted across all change records.
    public let insertedCharacters: Int
    /// The number of visible characters deleted across all change records.
    public let deletedCharacters: Int

    public init(
        changeRecordInsertions: Int,
        changeRecordDeletions: Int,
        insertedCharacters: Int,
        deletedCharacters: Int
    ) {
        self.changeRecordInsertions = changeRecordInsertions
        self.changeRecordDeletions = changeRecordDeletions
        self.insertedCharacters = insertedCharacters
        self.deletedCharacters = deletedCharacters
    }
}

/// A reusable diff payload that can be persisted or rendered later.
public struct TextDiffResult: Sendable, Equatable {
    /// The source text before edits.
    public let original: String
    /// The source text after edits.
    public let updated: String
    /// The comparison mode used to compute this result.
    public let mode: TextDiffComparisonMode
    /// Render-ready ordered segments for this diff.
    public let segments: [DiffSegment]
    /// Ordered insert/delete records after segment refinement and merging.
    public let changes: [TextDiffChange]
    /// Summary values derived from `changes`.
    public let summary: TextDiffSummary

    public init(
        original: String,
        updated: String,
        mode: TextDiffComparisonMode,
        segments: [DiffSegment],
        changes: [TextDiffChange],
        summary: TextDiffSummary
    ) {
        self.original = original
        self.updated = updated
        self.mode = mode
        self.segments = segments
        self.changes = changes
        self.summary = summary
    }
}
