import CoreGraphics
import Testing
@testable import TextDiff

@Test
@MainActor
func nsTextDiffViewInitComputesExactlyOnce() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    #expect(callCount == 1)
    #expect(view.intrinsicContentSize.height > 0)
}

@Test
@MainActor
func nsTextDiffViewRecomputesWhenOriginalChanges() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    view.original = "old-2"

    #expect(callCount == 2)
}

@Test
@MainActor
func nsTextDiffViewRecomputesWhenUpdatedChanges() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    view.updated = "new-2"

    #expect(callCount == 2)
}

@Test
@MainActor
func nsTextDiffViewRecomputesWhenModeChanges() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    view.mode = .character

    #expect(callCount == 2)
}

@Test
@MainActor
func nsTextDiffViewStyleChangeDoesNotRecomputeDiff() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    var style = TextDiffStyle.default
    style.removalsStyle.strikethrough = true
    view.style = style

    #expect(callCount == 1)
}

@Test
@MainActor
func nsTextDiffViewDebugInvisiblesToggleDoesNotRecomputeDiff() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    view.showsInvisibleCharacters = true
    view.showsInvisibleCharacters = false

    #expect(callCount == 1)
}

@Test
@MainActor
func nsTextDiffViewSetContentBatchesRecompute() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    var style = TextDiffStyle.default
    style.removalsStyle.strikethrough = true
    view.setContent(
        original: "old-2",
        updated: "new-2",
        style: style,
        mode: .character
    )

    #expect(callCount == 2)
}

@Test
@MainActor
func nsTextDiffViewSetContentStyleOnlyDoesNotRecomputeDiff() {
    var callCount = 0
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    ) { _, _, _ in
        callCount += 1
        return [DiffSegment(kind: .equal, tokenKind: .word, text: "\(callCount)")]
    }

    var style = TextDiffStyle.default
    style.removalsStyle.strikethrough = true
    view.setContent(
        original: "old",
        updated: "new",
        style: style,
        mode: .token
    )

    #expect(callCount == 1)
}

@Test
@MainActor
func nsTextDiffViewRevertDisabledDoesNotEmitAction() {
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 80)

    var captured: TextDiffRevertAction?
    view.onRevertAction = { action in
        captured = action
    }

    #expect(view._testingSetHoveredFirstRevertAction() == false)
    #expect(view._testingTriggerHoveredRevertAction() == false)
    #expect(captured == nil)
}

@Test
@MainActor
func nsTextDiffViewRevertSingleInsertionEmitsExpectedAction() throws {
    let view = NSTextDiffView(
        original: "cat",
        updated: "cat!",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 80)
    view.isRevertActionsEnabled = true

    var captured: TextDiffRevertAction?
    view.onRevertAction = { action in
        captured = action
    }

    #expect(view._testingSetHoveredFirstRevertAction() == true)
    #expect(view._testingTriggerHoveredRevertAction() == true)

    let action = try #require(captured)
    #expect(action.kind == .singleInsertion)
    #expect(action.replacementText == "")
    #expect(action.resultingUpdated == "cat")
}

@Test
@MainActor
func nsTextDiffViewRevertSingleDeletionEmitsExpectedAction() throws {
    let view = NSTextDiffView(
        original: "cat!",
        updated: "cat",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 80)
    view.isRevertActionsEnabled = true

    var captured: TextDiffRevertAction?
    view.onRevertAction = { action in
        captured = action
    }

    #expect(view._testingSetHoveredFirstRevertAction() == true)
    #expect(view._testingTriggerHoveredRevertAction() == true)

    let action = try #require(captured)
    #expect(action.kind == .singleDeletion)
    #expect(action.replacementText == "!")
    #expect(action.resultingUpdated == "cat!")
}

@Test
@MainActor
func nsTextDiffViewRevertPairEmitsExpectedAction() throws {
    let view = NSTextDiffView(
        original: "old",
        updated: "new",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 80)
    view.isRevertActionsEnabled = true

    var captured: TextDiffRevertAction?
    view.onRevertAction = { action in
        captured = action
    }

    #expect(view._testingSetHoveredFirstRevertAction() == true)
    #expect(view._testingTriggerHoveredRevertAction() == true)

    let action = try #require(captured)
    #expect(action.kind == .pairedReplacement)
    #expect(action.replacementText == "old")
    #expect(action.resultingUpdated == "old")
}

@Test
@MainActor
func hoverLeaveSchedulesDismissNotImmediate() {
    let view = NSTextDiffView(
        original: "old value",
        updated: "new value",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
    view.isRevertActionsEnabled = true
    view._testingEnableManualHoverDismissScheduler()

    let centers = view._testingActionCenters()
    #expect(centers.count == 1)
    guard let center = centers.first else {
        return
    }

    view._testingUpdateHover(location: center)
    #expect(view._testingHoveredActionID() != nil)

    view._testingUpdateHover(location: CGPoint(x: -10, y: -10))

    #expect(view._testingHasPendingHoverDismiss() == true)
    #expect(view._testingHoveredActionID() != nil)
}

@Test
@MainActor
func hoverDismissesAfterDelay() {
    let view = NSTextDiffView(
        original: "old value",
        updated: "new value",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
    view.isRevertActionsEnabled = true
    view._testingEnableManualHoverDismissScheduler()

    guard let center = view._testingActionCenters().first else {
        Issue.record("Expected at least one action center")
        return
    }
    view._testingUpdateHover(location: center)
    view._testingUpdateHover(location: CGPoint(x: -10, y: -10))
    #expect(view._testingHasPendingHoverDismiss() == true)

    #expect(view._testingRunNextScheduledHoverDismiss() == true)
    #expect(view._testingHoveredActionID() == nil)
    #expect(view._testingHasPendingHoverDismiss() == false)
}

@Test
@MainActor
func hoverSwitchesImmediatelyBetweenGroups() {
    let view = NSTextDiffView(
        original: "old A old B",
        updated: "new A new B",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 340, height: 110)
    view.isRevertActionsEnabled = true
    view._testingEnableManualHoverDismissScheduler()

    let centers = view._testingActionCenters()
    #expect(centers.count >= 2)
    guard centers.count >= 2 else {
        return
    }

    view._testingUpdateHover(location: centers[0])
    let firstAction = view._testingHoveredActionID()
    #expect(firstAction != nil)

    view._testingUpdateHover(location: centers[1])
    let secondAction = view._testingHoveredActionID()

    #expect(secondAction != nil)
    #expect(secondAction != firstAction)
    #expect(view._testingHasPendingHoverDismiss() == false)
}

@Test
@MainActor
func hoverReentryCancelsPendingDismiss() {
    let view = NSTextDiffView(
        original: "old value",
        updated: "new value",
        mode: .token
    )
    view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
    view.isRevertActionsEnabled = true
    view._testingEnableManualHoverDismissScheduler()

    guard let center = view._testingActionCenters().first else {
        Issue.record("Expected at least one action center")
        return
    }

    view._testingUpdateHover(location: center)
    let hovered = view._testingHoveredActionID()
    #expect(hovered != nil)

    view._testingUpdateHover(location: CGPoint(x: -10, y: -10))
    #expect(view._testingHasPendingHoverDismiss() == true)

    view._testingUpdateHover(location: center)
    #expect(view._testingHasPendingHoverDismiss() == false)
    #expect(view._testingHoveredActionID() == hovered)

    #expect(view._testingRunNextScheduledHoverDismiss() == true)
    #expect(view._testingHoveredActionID() == hovered)
}
