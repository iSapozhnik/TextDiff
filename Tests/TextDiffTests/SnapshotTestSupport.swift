import AppKit
import SnapshotTesting
import SwiftUI
import TextDiff

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

    assertSnapshot(
        of: hostingView,
        as: .image(size: size),
        named: name,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}
