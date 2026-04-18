import AppKit

enum DiffTextLayoutMetrics {
    static func verticalTextInset(for style: TextDiffStyle) -> CGFloat {
        ceil(max(0, style.chipInsets.top, style.chipInsets.bottom))
    }

    static func lineHeight(for style: TextDiffStyle) -> CGFloat {
        let textHeight = style.font.ascender - style.font.descender + style.font.leading
        let chipHeight = textHeight + style.chipInsets.top + style.chipInsets.bottom
        return ceil(chipHeight + max(0, style.lineSpacing))
    }
}
