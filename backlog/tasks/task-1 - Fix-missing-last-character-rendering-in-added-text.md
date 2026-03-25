---
id: TASK-1
title: Fix missing last character rendering in added text
status: Done
assignee: []
created_date: '2026-02-24 19:37'
updated_date: '2026-02-27 00:08'
labels:
  - bug
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
As a user comparing text diffs, I need every character in added text to be visible so I can trust what is shown on screen. There is an intermittent issue where the final character of an addition is not rendered visually, even though the character exists in the underlying text (for example, after pasting).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 When an addition is created by typing, the full added text is rendered including the final character.
- [x] #2 When the same addition is created by paste, the rendered result matches the typed result exactly with no missing final character.
- [x] #3 A regression test covers the scenario where the last character of an addition was previously not visible.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause:
The layouter measured token width for each run using cumulative line-width deltas (combinedWidth - previousLineWidth). With proportional fonts (for example .systemFont(ofSize: 13)), kerning/context shaping across token boundaries can make this delta slightly smaller than the token's standalone draw width. Because tokens are drawn individually in NSTextDiffView using run.textRect, the underestimated width could clip the trailing glyph (observed with "simply" where "y" disappeared in RevertBindingPreview).

Fix:
In DiffTokenLayouter, we now compute standalone token width and use max(incrementalWidth, standaloneWidth) for displayed changed lexical runs (insert/delete chips). This guarantees textRect/chip width is never narrower than the rendered token while preserving incremental measurement for line-flow decisions.

Regression coverage:
Added layouterPreventsInsertedTokenClipWithProportionalSystemFont in Tests/TextDiffTests/TextDiffEngineTests.swift to assert inserted "simply" width is at least standalone width and that chip bounds fully cover text bounds when using .systemFont(ofSize: 13).

Verification:
Ran swift test 2>&1 | xcsift and confirmed the new test executes and passes.
<!-- SECTION:NOTES:END -->
