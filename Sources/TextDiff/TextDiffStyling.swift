import AppKit

/// Change-specific visual configuration used for addition/removal rendering.
public protocol TextDiffStyling {
    /// Fill color used for chip backgrounds.
    var fillColor: NSColor { get }
    /// Stroke color used for chip outlines.
    var strokeColor: NSColor { get }
    /// Optional text color override for chip text.
    var textColorOverride: NSColor? { get }
    /// Whether changed lexical content should render with a strikethrough.
    var strikethrough: Bool { get }
}
