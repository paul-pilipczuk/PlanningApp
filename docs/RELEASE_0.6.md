# Planning 0.6 — Task experience

The 0.6 series is in development. This document records the initial local usability candidate; it does not mark the larger release as shipped. Subgroups and progress remain future scope.

## Versions

- [0.6.0 — Initial task usability batch](#v0-6-0)

<a id="v0-6-0"></a>

## 0.6.0 — Initial task usability batch

November 14, 2026 · Local candidate · Version 0.6.0, build 10

### Behavior

Real-user testing found that tapping task text could accidentally complete a plan. Active and Completed now have separate targets: the circle changes status, while task text opens details. The completion target is at least 44 points and has an explicit accessibility label. Active's existing drag interaction and trailing controls remain available.

Empty Active content is one full-area Add task button for touch and assistive technologies. It shows “No plans yet” and a short tap instruction, without an illustration or an additional Add button. The Active heading and its circular Add button also start creation. Floating navigation remains usable. Completing the final active task restores the large heading and expanded navigation.

Title's Done key dismisses the keyboard without saving. A labelled keyboard-down toolbar control is available while editing the title or multiline description. Descriptions retain Return for newlines; scrolling can dismiss the keyboard interactively.

The Group selector includes **New group**, opening a small form with Cancel and Create. Empty or duplicate names cannot be created. A successful save selects the new group; cancellation retains the previous selection. Group saves remain immediate, so cancelling the task afterwards does not remove a created group. A failed group save leaves the form open with feedback.

Weekly notifications now expose **Day** and **Time** together. Weekdays use localized names and the calendar's first-day ordering. Switching to Daily hides Day without clearing the stored weekly choice. The task editor and standalone notification form share the same controls. Existing reminder scheduling, completion cancellation, and repeat behavior remain intact.

### Continuity and scope

There is no task schema migration, subgroup model, progress calculation, or new dependency in this batch. Preserve local saves, rollback, copied-task identity, cancellation/scroll retention, cached collections, lazy rows, and revision-based task animations from 0.5.5.

This work stays on `0.6.0-task-usability` as focused local commits. The owner requested **no PR yet**; a larger 0.6.0 PR will follow later work.

### Validation

Checked November 14, 2026 with Xcode 26.6 (17F113), the iOS 26.5 SDK, and an iOS 17 deployment target. Unit and UI runs used separate simulator destinations.

| Check | Result | Local evidence |
| --- | --- | --- |
| Full unit suite, iOS 26.5 | 42 passed | `/tmp/planning-060-unit.xcresult` |
| Full unit suite, iOS 17.2 | 42 passed | `/tmp/planning-060-ios17-unit.xcresult` |
| Existing UI regressions, iOS 26.5 | 18 passed | `NavigationUITests` in `/tmp/planning-060-ui.xcresult` |
| Final usability scenarios, iOS 26.5 | Six passed | `/tmp/planning-060-usability-final.xcresult` |
| Narrow iPhone SE, iOS 17.2 | Six usability scenarios plus drag passed | `/tmp/planning-060-ios17-ui-final.xcresult` |
| Release iPhone device-SDK build, signing disabled | Passed | `/tmp/planning-060-release.log` |

All 24 current UI scenarios passed across the existing-regression and final-usability runs. The first UI runs exposed test-query issues: a new group appeared below the lazy list's visible content on SE, and tapping the outer switch label did not activate the native switch. The corrected tests use a memory-only empty Active fixture and tap the switch thumb. Initial failure bundles are retained; the final usability runs supersede those queries.

Visual review covered the light New group form and keyboard-down control, dark weekly controls on current iOS and narrow iOS 17, Active/Completed at large accessibility text sizes, and settled empty Active layouts on both devices. Empty captures initially caught the tab-title crossfade; capture now precedes that transition. The final empty-page checks passed again in `/tmp/planning-060-empty-final.xcresult` and `/tmp/planning-060-ios17-empty-final.xcresult`.

Code review checked separate completion/detail hit areas, group selection on Cancel/save failure, existing copy/archive/delete routes, reminder bindings, and the empty-page transition. Store projections, persistence, and notification scheduling logic are unchanged. Drag/scroll callbacks retain cached reads and threshold-only publication, without new per-frame collection transformations. Existing cache correctness, purge, revision, and collection benchmarks remain in the passing unit suite; no new phone-performance claim is made.

### Phone test checklist

1. Tap several Active task titles/descriptions, then Cancel details. Verify no task completes. Complete only through the circle; repeat the split in Completed.
2. Keep the existing drag, swipe, Copy, Archive, and confirmed Delete flows working. Cancel an editor/copy from a scrolled page and check its position is retained.
3. With no Active tasks, tap near the top, center, and bottom of the empty content and the Active heading. Cancel each draft. Verify the top Add and all four tabs remain usable. Complete the last task and repeat.
4. Edit a title and tap Done; use the keyboard-down control for a multiline description. Neither action should save the draft.
5. Choose New group in the selector, cancel it, then create a unique group. Verify selection, duplicate-name feedback, and saved grouping after relaunch.
6. On a real saved task, configure Weekly with a weekday and time, save/reopen, and check delivery with permission enabled. Change to Daily and back. Complete the task and verify reminder cancellation.
7. Check light/dark, large accessibility text, VoiceOver's separate completion/details targets and empty-page action, Reduce Motion, and Reduce Transparency. Compare interaction smoothness on a supported older iPhone with Low Power Mode off and on.

Simulator checks do not establish notification delivery, VoiceOver focus quality, or physical-phone frame rate and battery behavior.
