import CoreGraphics

package enum DiffRevertHitResolver {
    package static func actionIDForHitTarget(
        at point: CGPoint,
        context: DiffRevertInteractionContext,
        minimumTapTargetSize: CGSize
    ) -> Int? {
        let exactMatches = context.chipRectsByActionID.compactMap { actionID, rects -> HitMatch? in
            guard rects.contains(where: { $0.contains(point) }) else {
                return nil
            }
            return HitMatch(
                actionID: actionID,
                distanceSquared: distanceSquared(from: point, to: context.unionChipRectByActionID[actionID])
            )
        }

        if let exactMatch = nearestMatch(exactMatches) {
            return exactMatch.actionID
        }

        let expandedMatches = context.chipRectsByActionID.compactMap { actionID, rects -> HitMatch? in
            guard rects.contains(where: { expandedTapRect(for: $0, minimumTapTargetSize: minimumTapTargetSize).contains(point) }) else {
                return nil
            }
            return HitMatch(
                actionID: actionID,
                distanceSquared: distanceSquared(from: point, to: context.unionChipRectByActionID[actionID])
            )
        }

        return nearestMatch(expandedMatches)?.actionID
    }

    private static func nearestMatch(_ matches: [HitMatch]) -> HitMatch? {
        matches.min {
            if $0.distanceSquared == $1.distanceSquared {
                return $0.actionID < $1.actionID
            }
            return $0.distanceSquared < $1.distanceSquared
        }
    }

    private static func expandedTapRect(for rect: CGRect, minimumTapTargetSize: CGSize) -> CGRect {
        let widthDelta = max(0, minimumTapTargetSize.width - rect.width)
        let heightDelta = max(0, minimumTapTargetSize.height - rect.height)
        return rect.insetBy(dx: -(widthDelta / 2), dy: -(heightDelta / 2))
    }

    private static func distanceSquared(from point: CGPoint, to rect: CGRect?) -> CGFloat {
        guard let rect else {
            return .greatestFiniteMagnitude
        }
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        return (dx * dx) + (dy * dy)
    }

    private struct HitMatch {
        let actionID: Int
        let distanceSquared: CGFloat
    }
}
