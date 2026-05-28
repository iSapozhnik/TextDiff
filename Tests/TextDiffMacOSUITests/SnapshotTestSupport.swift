import AppKit
import SnapshotTesting
import SwiftUI
import TextDiff

private let snapshotPrecision: Float = 0.995
private let snapshotPerceptualPrecision: Float = 0.98

func snapshotRecordMode(
    default defaultMode: SnapshotTestingConfiguration.Record = .missing
) -> SnapshotTestingConfiguration.Record {
    guard
        let rawValue = ProcessInfo.processInfo.environment["SNAPSHOT_TESTING_RECORD"],
        let recordMode = SnapshotTestingConfiguration.Record(rawValue: rawValue)
    else {
        return defaultMode
    }

    return recordMode
}

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
    configureSnapshotArtifactsDirectory(filePath: filePath)
    let snapshotStyle = stableSnapshotStyle(from: style)

    let rootView = TextDiffView(
        original: original,
        updated: updated,
        style: snapshotStyle,
        mode: mode
    )
    .frame(width: size.width, height: size.height, alignment: .topLeading)
    .background(Color.white)

    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.layoutSubtreeIfNeeded()

    let snapshotImage = renderSnapshotImage1x(view: hostingView, size: size)

    withSnapshotTesting(diffTool: .ksdiff) {
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
}

@MainActor
func assertTextDiffSnapshot(
    result: TextDiffResult,
    style: TextDiffStyle = .default,
    size: CGSize,
    named name: String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    configureSnapshotArtifactsDirectory(filePath: filePath)
    let snapshotStyle = stableSnapshotStyle(from: style)

    let rootView = TextDiffView(result: result, style: snapshotStyle)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(Color.white)

    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.layoutSubtreeIfNeeded()

    let snapshotImage = renderSnapshotImage1x(view: hostingView, size: size)

    withSnapshotTesting(diffTool: .ksdiff) {
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
}

@MainActor
func assertNSTextDiffSnapshot(
    original: String,
    updated: String,
    mode: TextDiffComparisonMode = .token,
    style: TextDiffStyle = .default,
    size: CGSize,
    configureView: ((NSTextDiffView) -> Void)? = nil,
    named name: String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    configureSnapshotArtifactsDirectory(filePath: filePath)
    let snapshotStyle = stableSnapshotStyle(from: style)

    let diffView = NSTextDiffView(
        original: original,
        updated: updated,
        style: snapshotStyle,
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
    configureView?(diffView)
    container.layoutSubtreeIfNeeded()

    let snapshotImage = renderSnapshotImage1x(view: container, size: size)

    withSnapshotTesting(diffTool: .ksdiff) {
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
}

private func configureSnapshotArtifactsDirectory(filePath: StaticString) {
    if getenv("SNAPSHOT_ARTIFACTS") != nil {
        return
    }

    let fileURL = URL(fileURLWithPath: "\(filePath)")
    let repoRootURL = fileURL
        .deletingLastPathComponent() // TextDiffTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repo root
    let artifactsPath = repoRootURL.appendingPathComponent(".snapshot-artifacts", isDirectory: true).path
    setenv("SNAPSHOT_ARTIFACTS", artifactsPath, 1)
}

private func stableSnapshotStyle(from base: TextDiffStyle) -> TextDiffStyle {
    var style = base

    style.additionsStyle = stableSnapshotChangeStyle(
        from: base.additionsStyle,
        fillColor: NSColor(
            srgbRed: 0.29,
            green: 0.73,
            blue: 0.37,
            alpha: 1
        )
    )
    style.removalsStyle = stableSnapshotChangeStyle(
        from: base.removalsStyle,
        fillColor: NSColor(
            srgbRed: 0.96,
            green: 0.42,
            blue: 0.42,
            alpha: 1
        )
    )

    return style
}

private func stableSnapshotChangeStyle(
    from base: TextDiffChangeStyle,
    fillColor: NSColor
) -> TextDiffChangeStyle {
    var style = base
    style.fillColor = fillColor
    style.strokeColor = fillColor
    return style
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
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size
    view.cacheDisplay(in: view.bounds, to: rep)

    let image = NSImage(size: size)
    image.addRepresentation(rep)
    return image
}
