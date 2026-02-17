import AppKit
import Foundation

/// Visual configuration for rendering text diff segments.
public struct TextDiffStyle: @unchecked Sendable {
    /// Fill color used for inserted token chips.
    public var additionFillColor: NSColor
    /// Stroke color used for inserted token chips.
    public var additionStrokeColor: NSColor
    /// Optional text color override for inserted tokens.
    public var additionTextColorOverride: NSColor?

    /// Fill color used for deleted token chips.
    public var deletionFillColor: NSColor
    /// Stroke color used for deleted token chips.
    public var deletionStrokeColor: NSColor
    /// Optional text color override for deleted tokens.
    public var deletionTextColorOverride: NSColor?

    /// Text color used for unchanged tokens.
    public var unchangedTextColor: NSColor
    /// Font used for all rendered tokens.
    public var font: NSFont
    /// Corner radius applied to changed-token chips.
    public var chipCornerRadius: CGFloat
    /// Insets used to draw changed-token chips. Horizontal insets are floored to 3 points by the renderer.
    public var chipInsets: NSEdgeInsets
    /// Controls whether deleted lexical tokens are drawn with a strikethrough.
    public var deletionStrikethrough: Bool
    /// Minimum visual gap between adjacent changed lexical chips.
    public var interChipSpacing: CGFloat
    /// Additional vertical spacing between wrapped lines.
    public var lineSpacing: CGFloat

    /// Creates a style for rendering text diffs.
    ///
    /// - Parameters:
    ///   - additionFillColor: Fill color used for inserted token chips.
    ///   - additionStrokeColor: Stroke color used for inserted token chips.
    ///   - additionTextColorOverride: Optional text color override for inserted tokens.
    ///   - deletionFillColor: Fill color used for deleted token chips.
    ///   - deletionStrokeColor: Stroke color used for deleted token chips.
    ///   - deletionTextColorOverride: Optional text color override for deleted tokens.
    ///   - unchangedTextColor: Text color used for unchanged tokens.
    ///   - font: Font used for all rendered tokens.
    ///   - chipCornerRadius: Corner radius applied to changed-token chips.
    ///   - chipInsets: Insets applied around changed-token text when drawing chips.
    ///   - deletionStrikethrough: Whether deleted lexical tokens use a strikethrough.
    ///   - interChipSpacing: Gap between adjacent changed lexical chips.
    ///   - lineSpacing: Additional vertical spacing between wrapped lines.
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
        interChipSpacing: CGFloat = 0,
        lineSpacing: CGFloat = 2
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
        self.lineSpacing = lineSpacing
    }

    /// The default style tuned for system green insertions and system red deletions.
    public static let `default` = TextDiffStyle(
        additionFillColor: NSColor.systemGreen.withAlphaComponent(0.22),
        additionStrokeColor: NSColor.systemGreen.withAlphaComponent(0.65),
        deletionFillColor: NSColor.systemRed.withAlphaComponent(0.22),
        deletionStrokeColor: NSColor.systemRed.withAlphaComponent(0.65)
    )
}
