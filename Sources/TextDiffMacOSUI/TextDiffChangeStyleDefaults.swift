import AppKit

public extension TextDiffChangeStyle {
    static let defaultAddition = TextDiffChangeStyle(
        fillColor: NSColor.systemGreen.withAlphaComponent(0.22),
        strokeColor: NSColor.systemGreen.withAlphaComponent(0.65),
        textColorOverride: nil,
        strikethrough: false
    )

    static let defaultRemoval = TextDiffChangeStyle(
        fillColor: NSColor.systemRed.withAlphaComponent(0.22),
        strokeColor: NSColor.systemRed.withAlphaComponent(0.65),
        textColorOverride: nil,
        strikethrough: false
    )
}
