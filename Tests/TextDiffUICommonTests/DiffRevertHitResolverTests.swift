import CoreGraphics
import Testing
@testable import TextDiffUICommon

@Test
func exactChipHitWinsOverEarlierExpandedHitTarget() {
    let context = hitTestContext(
        firstRect: CGRect(x: 0, y: 0, width: 12, height: 20),
        secondRect: CGRect(x: 14, y: 0, width: 12, height: 20)
    )

    let actionID = DiffRevertHitResolver.actionIDForHitTarget(
        at: CGPoint(x: 20, y: 10),
        context: context,
        minimumTapTargetSize: CGSize(width: 44, height: 44)
    )

    #expect(actionID == 1)
}

@Test
func overlappingExpandedHitTargetsChooseNearestCandidate() {
    let context = hitTestContext(
        firstRect: CGRect(x: 0, y: 0, width: 8, height: 20),
        secondRect: CGRect(x: 30, y: 0, width: 8, height: 20)
    )

    let actionID = DiffRevertHitResolver.actionIDForHitTarget(
        at: CGPoint(x: 25, y: 10),
        context: context,
        minimumTapTargetSize: CGSize(width: 44, height: 44)
    )

    #expect(actionID == 1)
}

@Test
func pointOutsideExactAndExpandedTargetsReturnsNil() {
    let context = hitTestContext(
        firstRect: CGRect(x: 0, y: 0, width: 8, height: 20),
        secondRect: CGRect(x: 30, y: 0, width: 8, height: 20)
    )

    let actionID = DiffRevertHitResolver.actionIDForHitTarget(
        at: CGPoint(x: 100, y: 100),
        context: context,
        minimumTapTargetSize: CGSize(width: 44, height: 44)
    )

    #expect(actionID == nil)
}

private func hitTestContext(
    firstRect: CGRect,
    secondRect: CGRect
) -> DiffRevertInteractionContext {
    DiffRevertInteractionContext(
        candidatesByID: [:],
        runIndicesByActionID: [:],
        chipRectsByActionID: [
            0: [firstRect],
            1: [secondRect]
        ],
        unionChipRectByActionID: [
            0: firstRect,
            1: secondRect
        ]
    )
}
