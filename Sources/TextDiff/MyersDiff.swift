import Foundation

enum MyersDiff {
    struct Operation: Sendable, Equatable {
        let kind: DiffOperationKind
        let token: Tokenizer.Token
    }

    static func diff(original: [Tokenizer.Token], updated: [Tokenizer.Token]) -> [Operation] {
        let originalCount = original.count
        let updatedCount = updated.count

        if originalCount == 0 {
            return updated.map { Operation(kind: .insert, token: $0) }
        }

        if updatedCount == 0 {
            return original.map { Operation(kind: .delete, token: $0) }
        }

        let maxDistance = originalCount + updatedCount
        var frontier: [Int: Int] = [1: 0]
        var trace: [[Int: Int]] = [frontier]

        for distance in 0...maxDistance {
            var nextFrontier: [Int: Int] = [:]

            for diagonal in stride(from: -distance, through: distance, by: 2) {
                let xStart: Int
                if diagonal == -distance {
                    xStart = frontier[diagonal + 1, default: 0]
                } else if diagonal == distance {
                    xStart = frontier[diagonal - 1, default: -1] + 1
                } else {
                    let insertX = frontier[diagonal + 1, default: -1]
                    let deleteX = frontier[diagonal - 1, default: -1] + 1
                    // Left-biased tie-breaking: choose deletion path when equal.
                    xStart = deleteX >= insertX ? deleteX : insertX
                }

                var x = xStart
                var y = x - diagonal

                while x < originalCount, y < updatedCount, original[x] == updated[y] {
                    x += 1
                    y += 1
                }

                nextFrontier[diagonal] = x

                if x >= originalCount, y >= updatedCount {
                    trace.append(nextFrontier)
                    return backtrack(
                        trace: trace,
                        finalDistance: distance,
                        original: original,
                        updated: updated
                    )
                }
            }

            frontier = nextFrontier
            trace.append(frontier)
        }

        return []
    }

    private static func backtrack(
        trace: [[Int: Int]],
        finalDistance: Int,
        original: [Tokenizer.Token],
        updated: [Tokenizer.Token]
    ) -> [Operation] {
        var x = original.count
        var y = updated.count
        var operations: [Operation] = []

        if finalDistance > 0 {
            for distance in stride(from: finalDistance, to: 0, by: -1) {
                let previousFrontier = trace[distance]
                let diagonal = x - y

                let previousDiagonal: Int
                if diagonal == -distance {
                    previousDiagonal = diagonal + 1
                } else if diagonal == distance {
                    previousDiagonal = diagonal - 1
                } else {
                    let leftX = previousFrontier[diagonal - 1, default: -1]
                    let downX = previousFrontier[diagonal + 1, default: -1]
                    previousDiagonal = leftX < downX ? diagonal + 1 : diagonal - 1
                }

                let previousX = previousFrontier[previousDiagonal, default: 0]
                let previousY = previousX - previousDiagonal

                while x > previousX, y > previousY {
                    x -= 1
                    y -= 1
                    operations.append(Operation(kind: .equal, token: original[x]))
                }

                if x == previousX {
                    y -= 1
                    operations.append(Operation(kind: .insert, token: updated[y]))
                } else {
                    x -= 1
                    operations.append(Operation(kind: .delete, token: original[x]))
                }
            }
        }

        while x > 0, y > 0 {
            x -= 1
            y -= 1
            operations.append(Operation(kind: .equal, token: original[x]))
        }

        while x > 0 {
            x -= 1
            operations.append(Operation(kind: .delete, token: original[x]))
        }

        while y > 0 {
            y -= 1
            operations.append(Operation(kind: .insert, token: updated[y]))
        }

        return operations.reversed()
    }
}
