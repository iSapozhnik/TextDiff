# TextDiff

TextDiff is a macOS Swift package that computes token-level diffs and renders a merged, display-only SwiftUI view backed by a custom AppKit renderer.

## Requirements

- macOS 14+
- Swift tools 6.1+

## Installation

Add TextDiff as a Swift Package dependency in Xcode or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/TextDiff.git", branch: "main")
]
```

Then import:

```swift
import TextDiff
```

## Basic Usage

```swift
import SwiftUI
import TextDiff

struct DemoView: View {
    var body: some View {
        TextDiffView(
            original: "This is teh old sentence.",
            updated: "This is the updated sentence!"
        )
        .padding()
    }
}
```

## Custom Styling

```swift
import SwiftUI
import TextDiff

let customStyle = TextDiffStyle(
    additionFillColor: NSColor.systemGreen.withAlphaComponent(0.28),
    additionStrokeColor: NSColor.systemGreen.withAlphaComponent(0.75),
    deletionFillColor: NSColor.systemRed.withAlphaComponent(0.24),
    deletionStrokeColor: NSColor.systemRed.withAlphaComponent(0.75),
    unchangedTextColor: .labelColor,
    font: .monospacedSystemFont(ofSize: 15, weight: .regular),
    chipCornerRadius: 5,
    chipInsets: NSEdgeInsets(top: 1, left: 3, bottom: 1, right: 3),
    deletionStrikethrough: true,
    interChipSpacing: 4
)

struct StyledDemoView: View {
    var body: some View {
        TextDiffView(
            original: "A quick brown fox jumps over a lazy dog.",
            updated: "A quick fox hops over the lazy dog!",
            style: customStyle
        )
    }
}
```

## Behavior Notes

- Tokenization uses `NLTokenizer` (`.word`) and reconstructs punctuation/whitespace by filling range gaps.
- Matching is exact (case-sensitive and punctuation-sensitive).
- Replacements are rendered as adjacent delete then insert segments.
- Whitespace changes preserve the `updated` layout and stay visually neutral (no chips).
- Rendering is display-only (not selectable) to keep chip geometry deterministic.
- Default `interChipSpacing` is `4`, applied between adjacent changed lexical chips (words or punctuation).
- Chip horizontal padding is preserved with a minimum effective floor of 3pt per side.
- No synthetic spacer characters are inserted into the rendered text stream.
- Chip top/bottom clipping is prevented internally via explicit line-height and vertical content insets.
- Moved text is not detected as a move; it appears as delete + insert.
- Rendering uses a custom AppKit draw view bridged into SwiftUI.
