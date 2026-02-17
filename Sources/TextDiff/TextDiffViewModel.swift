import Combine
import Foundation

@MainActor
final class TextDiffViewModel: ObservableObject {
    typealias DiffProvider = (String, String, TextDiffComparisonMode) -> [DiffSegment]

    @Published private(set) var segments: [DiffSegment]

    private var lastOriginal: String
    private var lastUpdated: String
    private var lastModeKey: Int
    private let diffProvider: DiffProvider

    init(
        original: String,
        updated: String,
        mode: TextDiffComparisonMode,
        diffProvider: @escaping DiffProvider = { original, updated, mode in
            TextDiffEngine.diff(original: original, updated: updated, mode: mode)
        }
    ) {
        self.lastOriginal = original
        self.lastUpdated = updated
        self.lastModeKey = Self.modeKey(for: mode)
        self.diffProvider = diffProvider
        self.segments = diffProvider(original, updated, mode)
    }

    func updateIfNeeded(original: String, updated: String, mode: TextDiffComparisonMode) {
        let newModeKey = Self.modeKey(for: mode)
        guard original != lastOriginal || updated != lastUpdated || newModeKey != lastModeKey else {
            return
        }

        lastOriginal = original
        lastUpdated = updated
        lastModeKey = newModeKey
        segments = diffProvider(original, updated, mode)
    }

    private static func modeKey(for mode: TextDiffComparisonMode) -> Int {
        switch mode {
        case .token:
            return 0
        case .character:
            return 1
        }
    }
}
