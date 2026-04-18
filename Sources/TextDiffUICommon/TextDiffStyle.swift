import Foundation

/// Visual configuration for rendering text diff segments.
public struct TextDiffStyle: @unchecked Sendable {
    /// Visual style used for inserted token chips.
    public var additionsStyle: TextDiffChangeStyle
    /// Visual style used for deleted token chips.
    public var removalsStyle: TextDiffChangeStyle

    /// Text color used for unchanged tokens.
    public var textColor: PlatformColor
    /// Font used for all rendered tokens.
    public var font: PlatformFont
    /// Corner radius applied to changed-token chips.
    public var chipCornerRadius: CGFloat
    /// Insets used to draw changed-token chips. Horizontal insets are floored to 3 points by the renderer.
    public var chipInsets: TextDiffEdgeInsets
    /// Minimum visual gap between adjacent changed lexical chips.
    public var interChipSpacing: CGFloat
    /// Additional vertical spacing between wrapped lines.
    public var lineSpacing: CGFloat
    /// Stroke style used for interactive revert-group outlines.
    public var groupStrokeStyle: TextDiffGroupStrokeStyle

    /// Creates a style for rendering text diffs.
    ///
    /// - Parameters:
    ///   - additionsStyle: Change style used for inserted token chips.
    ///   - removalsStyle: Change style used for deleted token chips.
    ///   - textColor: Text color used for unchanged tokens.
    ///   - font: Font used for all rendered tokens.
    ///   - chipCornerRadius: Corner radius applied to changed-token chips.
    ///   - chipInsets: Insets applied around changed-token text when drawing chips.
    ///   - interChipSpacing: Gap between adjacent changed lexical chips.
    ///   - lineSpacing: Additional vertical spacing between wrapped lines.
    ///   - groupStrokeStyle: Stroke style for revert-group hover outlines.
    public init(
        additionsStyle: TextDiffChangeStyle = .defaultAddition,
        removalsStyle: TextDiffChangeStyle = .defaultRemoval,
        textColor: PlatformColor = TextDiffStyle.defaultTextColorValue,
        font: PlatformFont = TextDiffStyle.defaultTextFontValue,
        chipCornerRadius: CGFloat = 4,
        chipInsets: TextDiffEdgeInsets = TextDiffEdgeInsets(top: 1, left: 3, bottom: 1, right: 3),
        interChipSpacing: CGFloat = 0,
        lineSpacing: CGFloat = 2,
        groupStrokeStyle: TextDiffGroupStrokeStyle = .solid
    ) {
        self.additionsStyle = additionsStyle
        self.removalsStyle = removalsStyle
        self.textColor = textColor
        self.font = font
        self.chipCornerRadius = chipCornerRadius
        self.chipInsets = chipInsets
        self.interChipSpacing = interChipSpacing
        self.lineSpacing = lineSpacing
        self.groupStrokeStyle = groupStrokeStyle
    }

    /// Creates a style by converting protocol-based operation styles to concrete change styles.
    ///
    /// - Parameters:
    ///   - additionsStyle: Protocol-based style for inserted token chips.
    ///   - removalsStyle: Protocol-based style for deleted token chips.
    ///   - textColor: Text color used for unchanged tokens.
    ///   - font: Font used for all rendered tokens.
    ///   - chipCornerRadius: Corner radius applied to changed-token chips.
    ///   - chipInsets: Insets applied around changed-token text when drawing chips.
    ///   - interChipSpacing: Gap between adjacent changed lexical chips.
    ///   - lineSpacing: Additional vertical spacing between wrapped lines.
    ///   - groupStrokeStyle: Stroke style for revert-group hover outlines.
    public init(
        additionsStyle: some TextDiffStyling,
        removalsStyle: some TextDiffStyling,
        textColor: PlatformColor = TextDiffStyle.defaultTextColorValue,
        font: PlatformFont = TextDiffStyle.defaultTextFontValue,
        chipCornerRadius: CGFloat = 4,
        chipInsets: TextDiffEdgeInsets = TextDiffEdgeInsets(top: 1, left: 3, bottom: 1, right: 3),
        interChipSpacing: CGFloat = 0,
        lineSpacing: CGFloat = 2,
        groupStrokeStyle: TextDiffGroupStrokeStyle = .solid
    ) {
        self.init(
            additionsStyle: TextDiffChangeStyle(additionsStyle),
            removalsStyle: TextDiffChangeStyle(removalsStyle),
            textColor: textColor,
            font: font,
            chipCornerRadius: chipCornerRadius,
            chipInsets: chipInsets,
            interChipSpacing: interChipSpacing,
            lineSpacing: lineSpacing,
            groupStrokeStyle: groupStrokeStyle
        )
    }

    /// The default style tuned for system green insertions and system red deletions.
    public static let `default` = TextDiffStyle()

    #if canImport(AppKit)
    public static var defaultTextColorValue: PlatformColor { .labelColor }
    public static var defaultTextFontValue: PlatformFont { .monospacedSystemFont(ofSize: 14, weight: .regular) }
    #elseif canImport(UIKit)
    public static var defaultTextColorValue: PlatformColor { .label }
    public static var defaultTextFontValue: PlatformFont { .monospacedSystemFont(ofSize: 14, weight: .regular) }
    #endif
}
