import AppKit

enum DiffTextLayoutMetrics {
    static func verticalTextInset(for style: TextDiffStyle) -> CGFloat {
        ceil(max(2, style.chipInsets.top + 2, style.chipInsets.bottom + 2))
    }

    static func lineHeight(for style: TextDiffStyle) -> CGFloat {
        let textHeight = ceil(style.font.ascender - style.font.descender + style.font.leading)
        let chipHeight = textHeight + style.chipInsets.top + style.chipInsets.bottom
        return ceil(chipHeight + max(0, style.lineSpacing))
    }
}
