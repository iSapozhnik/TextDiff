---
id: TASK-1
title: Fix missing last character rendering in added text
status: To Do
assignee: []
created_date: '2026-02-24 19:37'
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
- [ ] #1 When an addition is created by typing, the full added text is rendered including the final character.
- [ ] #2 When the same addition is created by paste, the rendered result matches the typed result exactly with no missing final character.
- [ ] #3 A regression test covers the scenario where the last character of an addition was previously not visible.
<!-- AC:END -->
