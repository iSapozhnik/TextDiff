import Foundation

/// Concrete change style used for additions and removals.
public struct TextDiffChangeStyle: TextDiffStyling, @unchecked Sendable {
    public var fillColor: PlatformColor
    public var strokeColor: PlatformColor
    public var textColorOverride: PlatformColor?
    public var strikethrough: Bool

    public init(
        fillColor: PlatformColor,
        strokeColor: PlatformColor,
        textColorOverride: PlatformColor? = nil,
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
