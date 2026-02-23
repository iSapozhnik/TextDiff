import AppKit
import Foundation

struct LaidOutRun {
    let segment: DiffSegment
    let attributedText: NSAttributedString
    let textRect: CGRect
    let chipRect: CGRect?
    let chipFillColor: NSColor?
    let chipStrokeColor: NSColor?
    let chipCornerRadius: CGFloat
    let isChangedLexical: Bool
}

struct DiffLayout {
    let runs: [LaidOutRun]
    let contentSize: CGSize
}

enum DiffTokenLayouter {
    private static let minimumHorizontalChipPadding: CGFloat = 3

    static func layout(
        segments: [DiffSegment],
        style: TextDiffStyle,
        availableWidth: CGFloat,
        contentInsets: NSEdgeInsets
    ) -> DiffLayout {
        let lineHeight = DiffTextLayoutMetrics.lineHeight(for: style)
        let textHeight = ceil(style.font.ascender - style.font.descender + style.font.leading)
        let maxLineWidth = availableWidth > 0 ? availableWidth : .greatestFiniteMagnitude
        let lineStartX = contentInsets.left
        let maxLineX = lineStartX + maxLineWidth

        var runs: [LaidOutRun] = []
        var cursorX = lineStartX
        var lineTop = contentInsets.top
        var maxUsedX = lineStartX
        var lineCount = 1
        var lineHasContent = false
        let lineText = NSMutableString()
        var lineTextWidth: CGFloat = 0
        var previousChangedLexical = false

        func moveToNewLine() {
            lineTop += lineHeight
            cursorX = lineStartX
            lineHasContent = false
            lineText.setString("")
            lineTextWidth = 0
            previousChangedLexical = false
            lineCount += 1
        }

        for piece in pieces(from: segments) {
            if piece.isLineBreak {
                moveToNewLine()
                continue
            }

            guard !piece.text.isEmpty else {
                continue
            }

            let segment = DiffSegment(kind: piece.kind, tokenKind: piece.tokenKind, text: piece.text)
            let isChangedLexical = segment.kind != .equal && segment.tokenKind != .whitespace
            var leadingGap: CGFloat = 0
            if previousChangedLexical && isChangedLexical {
                leadingGap = max(0, style.interChipSpacing)
            }

            let attributedText = attributedToken(for: segment, style: style)
            var textMeasurement = measuredIncrementalTextWidth(
                for: piece.text,
                font: style.font,
                lineText: lineText,
                lineTextWidth: lineTextWidth
            )
            var textSize = CGSize(width: textMeasurement.textWidth, height: textHeight)
            let chipInsets = effectiveChipInsets(for: style)
            var runWidth = isChangedLexical ? textSize.width + chipInsets.left + chipInsets.right : textSize.width
            let requiredWidth = leadingGap + runWidth

            let wrapped = lineHasContent && cursorX + requiredWidth > maxLineX
            if wrapped {
                moveToNewLine()
                leadingGap = 0

                // Soft-wrap boundary: do not carry inter-word whitespace to next line.
                if piece.tokenKind == .whitespace {
                    continue
                }

                textMeasurement = measuredIncrementalTextWidth(
                    for: piece.text,
                    font: style.font,
                    lineText: lineText,
                    lineTextWidth: lineTextWidth
                )
                textSize = CGSize(width: textMeasurement.textWidth, height: textHeight)
                runWidth = isChangedLexical ? textSize.width + chipInsets.left + chipInsets.right : textSize.width
            }

            cursorX += leadingGap
            let textY = lineTop + ((lineHeight - textSize.height) / 2)
            let textX = cursorX + (isChangedLexical ? chipInsets.left : 0)
            let textRect = CGRect(origin: CGPoint(x: textX, y: textY), size: textSize)

            var chipRect: CGRect?
            var chipFillColor: NSColor?
            var chipStrokeColor: NSColor?
            if isChangedLexical {
                let chipHeight = textSize.height + chipInsets.top + chipInsets.bottom
                let chipY = lineTop + ((lineHeight - chipHeight) / 2)
                chipRect = CGRect(
                    x: cursorX,
                    y: chipY,
                    width: runWidth,
                    height: chipHeight
                )
                chipFillColor = chipFillColorForOperation(segment.kind, style: style)
                chipStrokeColor = chipStrokeColorForOperation(segment.kind, style: style)
            }

            runs.append(
                LaidOutRun(
                    segment: segment,
                    attributedText: attributedText,
                    textRect: textRect,
                    chipRect: chipRect,
                    chipFillColor: chipFillColor,
                    chipStrokeColor: chipStrokeColor,
                    chipCornerRadius: style.chipCornerRadius,
                    isChangedLexical: isChangedLexical
                )
            )

            cursorX += runWidth
            maxUsedX = max(maxUsedX, cursorX)
            lineHasContent = true
            lineTextWidth = textMeasurement.combinedLineWidth
            previousChangedLexical = isChangedLexical
        }

        let contentHeight = contentInsets.top + contentInsets.bottom + (CGFloat(lineCount) * lineHeight)
        let usedWidth = maxUsedX + contentInsets.right
        let intrinsicWidth = availableWidth.isFinite && availableWidth > 0
            ? (contentInsets.left + availableWidth + contentInsets.right)
            : usedWidth

        return DiffLayout(
            runs: runs,
            contentSize: CGSize(width: max(intrinsicWidth, usedWidth), height: contentHeight)
        )
    }

    private static func attributedToken(for segment: DiffSegment, style: TextDiffStyle) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: textColor(for: segment, style: style)
        ]

        if style.removalsStyle.strikethrough, segment.kind == .delete, segment.tokenKind != .whitespace {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        return NSAttributedString(string: segment.text, attributes: attributes)
    }

    private static func measuredIncrementalTextWidth(
        for text: String,
        font: NSFont,
        lineText: NSMutableString,
        lineTextWidth: CGFloat
    ) -> IncrementalTextWidth {
        guard !text.isEmpty else {
            return IncrementalTextWidth(
                textWidth: 0,
                combinedLineWidth: lineTextWidth
            )
        }

        lineText.append(text)
        let combinedWidth = lineText.size(withAttributes: [.font: font]).width
        let textWidth = max(0, combinedWidth - lineTextWidth)
        return IncrementalTextWidth(
            textWidth: textWidth,
            combinedLineWidth: combinedWidth
        )
    }

    private static func effectiveChipInsets(for style: TextDiffStyle) -> NSEdgeInsets {
        NSEdgeInsets(
            top: style.chipInsets.top,
            left: max(style.chipInsets.left, minimumHorizontalChipPadding),
            bottom: style.chipInsets.bottom,
            right: max(style.chipInsets.right, minimumHorizontalChipPadding)
        )
    }

    private static func textColor(for segment: DiffSegment, style: TextDiffStyle) -> NSColor {
        switch segment.kind {
        case .equal:
            return style.textColor
        case .delete:
            if let override = style.removalsStyle.textColorOverride {
                return override
            }
            return adaptiveChipTextColor(for: style.removalsStyle.fillColor)
        case .insert:
            if let override = style.additionsStyle.textColorOverride {
                return override
            }
            return adaptiveChipTextColor(for: style.additionsStyle.fillColor)
        }
    }

    private static func chipFillColorForOperation(_ kind: DiffOperationKind, style: TextDiffStyle) -> NSColor? {
        switch kind {
        case .delete:
            return style.removalsStyle.fillColor
        case .insert:
            return style.additionsStyle.fillColor
        case .equal:
            return nil
        }
    }

    private static func chipStrokeColorForOperation(_ kind: DiffOperationKind, style: TextDiffStyle) -> NSColor? {
        switch kind {
        case .delete:
            return style.removalsStyle.strokeColor
        case .insert:
            return style.additionsStyle.strokeColor
        case .equal:
            return nil
        }
    }

    private static func adaptiveChipTextColor(for fillColor: NSColor) -> NSColor {
        let rgb = fillColor.usingColorSpace(.deviceRGB) ?? fillColor
        let luminance = (0.2126 * rgb.redComponent) + (0.7152 * rgb.greenComponent) + (0.0722 * rgb.blueComponent)
        if luminance > 0.55 {
            return NSColor.black.withAlphaComponent(0.9)
        }
        return NSColor.white.withAlphaComponent(0.95)
    }

    private static func pieces(from segments: [DiffSegment]) -> [LayoutPiece] {
        var output: [LayoutPiece] = []
        output.reserveCapacity(segments.count)

        for segment in segments {
            var buffer = ""
            for scalar in segment.text.unicodeScalars {
                if scalar == "\n" {
                    if !buffer.isEmpty {
                        output.append(
                            LayoutPiece(
                                kind: segment.kind,
                                tokenKind: segment.tokenKind,
                                text: buffer,
                                isLineBreak: false
                            )
                        )
                        buffer.removeAll(keepingCapacity: true)
                    }
                    output.append(
                        LayoutPiece(
                            kind: segment.kind,
                            tokenKind: .whitespace,
                            text: "",
                            isLineBreak: true
                        )
                    )
                } else {
                    buffer.unicodeScalars.append(scalar)
                }
            }

            if !buffer.isEmpty {
                output.append(
                    LayoutPiece(
                        kind: segment.kind,
                        tokenKind: segment.tokenKind,
                        text: buffer,
                        isLineBreak: false
                    )
                )
            }
        }

        return output
    }
}

private struct LayoutPiece {
    let kind: DiffOperationKind
    let tokenKind: DiffTokenKind
    let text: String
    let isLineBreak: Bool
}

private struct IncrementalTextWidth {
    let textWidth: CGFloat
    let combinedLineWidth: CGFloat
}
