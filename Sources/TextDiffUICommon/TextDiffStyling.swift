/// Change-specific visual configuration used for addition/removal rendering.
public protocol TextDiffStyling {
    /// Fill color used for chip backgrounds.
    var fillColor: PlatformColor { get }
    /// Stroke color used for chip outlines.
    var strokeColor: PlatformColor { get }
    /// Optional text color override for chip text.
    var textColorOverride: PlatformColor? { get }
    /// Whether changed lexical content should render with a strikethrough.
    var strikethrough: Bool { get }
}
