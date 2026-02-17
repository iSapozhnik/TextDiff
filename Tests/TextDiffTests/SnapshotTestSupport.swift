import AppKit
import SnapshotTesting
import SwiftUI
import TextDiff

private let snapshotPrecision: Float = 0.995
private let snapshotPerceptualPrecision: Float = 0.99

@MainActor
func assertTextDiffSnapshot(
    original: String,
    updated: String,
    mode: TextDiffComparisonMode = .token,
    style: TextDiffStyle = .default,
    size: CGSize,
    named name: String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let rootView = TextDiffView(
        original: original,
        updated: updated,
        style: style,
        mode: mode
    )
    .frame(width: size.width, height: size.height, alignment: .topLeading)
    .background(Color.white)

    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.layoutSubtreeIfNeeded()

    let snapshotImage = renderSnapshotImage1x(view: hostingView, size: size)

    assertSnapshot(
        of: snapshotImage,
        as: .image(
            precision: snapshotPrecision,
            perceptualPrecision: snapshotPerceptualPrecision
        ),
        named: name,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}

@MainActor
func assertNSTextDiffSnapshot(
    original: String,
    updated: String,
    mode: TextDiffComparisonMode = .token,
    style: TextDiffStyle = .default,
    size: CGSize,
    named name: String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let diffView = NSTextDiffView(
        original: original,
        updated: updated,
        style: style,
        mode: mode
    )

    let container = NSView(frame: CGRect(origin: .zero, size: size))
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor.white.cgColor
    container.appearance = NSAppearance(named: .aqua)

    diffView.frame = container.bounds
    diffView.autoresizingMask = [.width, .height]
    container.addSubview(diffView)
    container.layoutSubtreeIfNeeded()

    let snapshotImage = renderSnapshotImage1x(view: container, size: size)

    assertSnapshot(
        of: snapshotImage,
        as: .image(
            precision: snapshotPrecision,
            perceptualPrecision: snapshotPerceptualPrecision
        ),
        named: name,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}

@MainActor
private func renderSnapshotImage1x(view: NSView, size: CGSize) -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size
    view.cacheDisplay(in: view.bounds, to: rep)

    let image = NSImage(size: size)
    image.addRepresentation(rep)
    return image
}
