import Foundation
import TextDiffCore

enum NSTextDiffContentSource {
    case text
    case result(TextDiffResult)

    var isResultDriven: Bool {
        if case .result = self {
            return true
        }
        return false
    }
}
