import AppKit
import Foundation

/// Concrete change style used for additions and removals.
public struct TextDiffChangeStyle: TextDiffStyling, @unchecked Sendable {
    public var fillColor: NSColor
    public var strokeColor: NSColor
    public var textColorOverride: NSColor?
    public var strikethrough: Bool

    public init(
        fillColor: NSColor,
        strokeColor: NSColor,
        textColorOverride: NSColor? = nil,
        strikethrough: Bool = false
    ) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColorOverride = textColorOverride
        self.strikethrough = strikethrough
    }

    public init(_ styling: some TextDiffStyling) {
        self.fillColor = styling.fillColor
        self.strokeColor = styling.strokeColor
        self.textColorOverride = styling.textColorOverride
        self.strikethrough = styling.strikethrough
    }
}
