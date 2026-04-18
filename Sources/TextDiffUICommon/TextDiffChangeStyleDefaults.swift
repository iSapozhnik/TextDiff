public extension TextDiffChangeStyle {
    static let defaultAddition = TextDiffChangeStyle(
        fillColor: defaultAdditionFillColorValue,
        strokeColor: defaultAdditionStrokeColorValue,
        textColorOverride: nil,
        strikethrough: false
    )

    static let defaultRemoval = TextDiffChangeStyle(
        fillColor: defaultRemovalFillColorValue,
        strokeColor: defaultRemovalStrokeColorValue,
        textColorOverride: defaultRemovalTextColorValue,
        strikethrough: false
    )
}

#if canImport(AppKit)
private var defaultAdditionFillColorValue: PlatformColor { PlatformColor.systemGreen.withAlphaComponent(0.22) }
private var defaultAdditionStrokeColorValue: PlatformColor { PlatformColor.systemGreen.withAlphaComponent(0.65) }
private var defaultRemovalFillColorValue: PlatformColor { PlatformColor.systemRed.withAlphaComponent(0.22) }
private var defaultRemovalStrokeColorValue: PlatformColor { PlatformColor.systemRed.withAlphaComponent(0.65) }
private var defaultRemovalTextColorValue: PlatformColor { PlatformColor.labelColor }
#elseif canImport(UIKit)
private var defaultAdditionFillColorValue: PlatformColor { PlatformColor.systemGreen.withAlphaComponent(0.22) }
private var defaultAdditionStrokeColorValue: PlatformColor { PlatformColor.systemGreen.withAlphaComponent(0.65) }
private var defaultRemovalFillColorValue: PlatformColor { PlatformColor.systemRed.withAlphaComponent(0.22) }
private var defaultRemovalStrokeColorValue: PlatformColor { PlatformColor.systemRed.withAlphaComponent(0.65) }
private var defaultRemovalTextColorValue: PlatformColor { PlatformColor.label }
#endif
