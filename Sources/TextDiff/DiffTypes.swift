import Foundation

public enum DiffTokenKind: Sendable {
    case word
    case punctuation
    case whitespace
}

public enum DiffOperationKind: Sendable {
    case equal
    case delete
    case insert
}

public struct DiffSegment: Sendable, Equatable {
    public let kind: DiffOperationKind
    public let tokenKind: DiffTokenKind
    public let text: String

    public init(kind: DiffOperationKind, tokenKind: DiffTokenKind, text: String) {
        self.kind = kind
        self.tokenKind = tokenKind
        self.text = text
    }
}
