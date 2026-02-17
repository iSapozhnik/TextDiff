import AppKit
import Foundation

public struct TextDiffStyle: @unchecked Sendable {
    public var additionFillColor: NSColor
    public var additionStrokeColor: NSColor
    public var additionTextColorOverride: NSColor?

    public var deletionFillColor: NSColor
    public var deletionStrokeColor: NSColor
    public var deletionTextColorOverride: NSColor?

    public var unchangedTextColor: NSColor
    public var font: NSFont
    public var chipCornerRadius: CGFloat
    /// Insets used to draw changed-token chips. Horizontal insets are floored to 3pt by the renderer.
    public var chipInsets: NSEdgeInsets
    public var deletionStrikethrough: Bool
    /// Minimum visual gap between adjacent changed lexical chips (word or punctuation).
    public var interChipSpacing: CGFloat

    public init(
        additionFillColor: NSColor,
        additionStrokeColor: NSColor,
        additionTextColorOverride: NSColor? = nil,
        deletionFillColor: NSColor,
        deletionStrokeColor: NSColor,
        deletionTextColorOverride: NSColor? = nil,
        unchangedTextColor: NSColor = .labelColor,
        font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular),
        chipCornerRadius: CGFloat = 4,
        chipInsets: NSEdgeInsets = NSEdgeInsets(top: 1, left: 3, bottom: 1, right: 3),
        deletionStrikethrough: Bool = false,
        interChipSpacing: CGFloat = 0
    ) {
        self.additionFillColor = additionFillColor
        self.additionStrokeColor = additionStrokeColor
        self.additionTextColorOverride = additionTextColorOverride
        self.deletionFillColor = deletionFillColor
        self.deletionStrokeColor = deletionStrokeColor
        self.deletionTextColorOverride = deletionTextColorOverride
        self.unchangedTextColor = unchangedTextColor
        self.font = font
        self.chipCornerRadius = chipCornerRadius
        self.chipInsets = chipInsets
        self.deletionStrikethrough = deletionStrikethrough
        self.interChipSpacing = interChipSpacing
    }

    public static let `default` = TextDiffStyle(
        additionFillColor: NSColor.systemGreen.withAlphaComponent(0.22),
        additionStrokeColor: NSColor.systemGreen.withAlphaComponent(0.65),
        deletionFillColor: NSColor.systemRed.withAlphaComponent(0.22),
        deletionStrokeColor: NSColor.systemRed.withAlphaComponent(0.65)
    )
}
