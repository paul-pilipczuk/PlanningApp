# Planning 0.6 — Task experience

The 0.6 series is in development. This document records the local usability and optional task-progress candidate; it does not mark the larger release as shipped. Arbitrary nested subgroups and subgroup-derived numeric progress remain future scope.

## Versions

- [0.6.0 — Task usability and optional progress](#v0-6-0)

<a id="v0-6-0"></a>

## 0.6.0 — Task usability and optional progress

November 14–16, 2026 · Local candidate · Version 0.6.0, build 12

The initial usability checkpoint describes build 10, the progress checkpoint describes build 11, and the keyboard/header follow-up describes the current build 12.

### Initial usability checkpoint — build 10

#### Behavior

Real-user testing found that tapping task text could accidentally complete a plan. Active and Completed now have separate targets: the circle changes status, while task text opens details. The completion target is at least 44 points and has an explicit accessibility label. Active's existing drag interaction and trailing controls remain available.

Empty Active content is one full-area Add task button for touch and assistive technologies. It shows “No plans yet” and a short tap instruction, without an illustration or an additional Add button. The Active heading and its circular Add button also start creation. Floating navigation remains usable. Completing the final active task restores the large heading and expanded navigation.

Title's Done key dismisses the keyboard without saving. A labelled keyboard-down control is available while editing the title or multiline description. Descriptions retain Return for newlines; scrolling can dismiss the keyboard interactively.

The Group selector includes **New group**, opening a small form with Cancel and Create. Empty or duplicate names cannot be created. A successful save selects the new group; cancellation retains the previous selection. Group saves remain immediate, so cancelling the task afterwards does not remove a created group. A failed group save leaves the form open with feedback.

Weekly notifications now expose **Day** and **Time** together. Weekdays use localized names and the calendar's first-day ordering. Switching to Daily hides Day without clearing the stored weekly choice. The task editor and standalone notification form share the same controls. Existing reminder scheduling, completion cancellation, and repeat behavior remain intact.

#### Continuity and scope

There is no task schema migration, subgroup model, progress calculation, or new dependency in this batch. Preserve local saves, rollback, copied-task identity, cancellation/scroll retention, cached collections, lazy rows, and revision-based task animations from 0.5.5.

This work stays on `0.6.0-task-usability` as focused local commits. The owner requested **no PR yet**; a larger 0.6.0 PR will follow later work.

#### Validation

Checked November 14, 2026 with Xcode 26.6 (17F113), the iOS 26.5 SDK, and an iOS 17 deployment target. Unit and UI runs used separate simulator destinations.

| Check | Result | Local evidence |
| --- | --- | --- |
| Full unit suite, iOS 26.5 | 42 passed | `/tmp/planning-060-unit.xcresult` |
| Full unit suite, iOS 17.2 | 42 passed | `/tmp/planning-060-ios17-unit.xcresult` |
| Existing UI regressions, iOS 26.5 | 18 passed | `NavigationUITests` in `/tmp/planning-060-ui.xcresult` |
| Final usability scenarios, iOS 26.5 | Six passed | `/tmp/planning-060-usability-final.xcresult` |
| Narrow iPhone SE, iOS 17.2 | Six usability scenarios plus drag passed | `/tmp/planning-060-ios17-ui-final.xcresult` |
| Release iPhone device-SDK build, signing disabled | Passed | `/tmp/planning-060-release.log` |

All 24 UI scenarios at this checkpoint passed across the existing-regression and final-usability runs. The first UI runs exposed test-query issues: a new group appeared below the lazy list's visible content on SE, and tapping the outer switch label did not activate the native switch. The corrected tests use a memory-only empty Active fixture and tap the switch thumb. Initial failure bundles are retained; the final usability runs supersede those queries.

Visual review covered the light New group form and keyboard-down control, dark weekly controls on current iOS and narrow iOS 17, Active/Completed at large accessibility text sizes, and settled empty Active layouts on both devices. Empty captures initially caught the tab-title crossfade; capture now precedes that transition. The final empty-page checks passed again in `/tmp/planning-060-empty-final.xcresult` and `/tmp/planning-060-ios17-empty-final.xcresult`.

Code review checked separate completion/detail hit areas, group selection on Cancel/save failure, existing copy/archive/delete routes, reminder bindings, and the empty-page transition. Store projections, persistence, and notification scheduling logic are unchanged. Drag/scroll callbacks retain cached reads and threshold-only publication, without new per-frame collection transformations. Existing cache correctness, purge, revision, and collection benchmarks remain in the passing unit suite; no new phone-performance claim is made.

#### Phone test checklist

1. Tap several Active task titles/descriptions, then Cancel details. Verify no task completes. Complete only through the circle; repeat the split in Completed.
2. Keep the existing drag, swipe, Copy, Archive, and confirmed Delete flows working. Cancel an editor/copy from a scrolled page and check its position is retained.
3. With no Active tasks, tap near the top, center, and bottom of the empty content and the Active heading. Cancel each draft. Verify the top Add and all four tabs remain usable. Complete the last task and repeat.
4. Edit a title and tap Done; use the keyboard-down control for a multiline description. Neither action should save the draft.
5. Choose New group in the selector, cancel it, then create a unique group. Verify selection, duplicate-name feedback, and saved grouping after relaunch.
6. On a real saved task, configure Weekly with a weekday and time, save/reopen, and check delivery with permission enabled. Change to Daily and back. Complete the task and verify reminder cancellation.
7. Check light/dark, large accessibility text, VoiceOver's separate completion/details targets and empty-page action, Reduce Motion, and Reduce Transparency. Compare interaction smoothness on a supported older iPhone with Low Power Mode off and on.

Simulator checks do not establish notification delivery, VoiceOver focus quality, or physical-phone frame rate and battery behavior.


<a id="v0-6-0-task-progress"></a>

### Task progress checkpoint — build 11

November 15–16, 2026 · Still local-only; no push or PR

#### What to try

**Task progress** starts off. Enable it in Settings to expand **To do** and **In progress**. **Edit labels** opens a draft editor with native Edit controls for reordering/removal and ordinary label rows for renaming. Add custom labels and remove either or both defaults, keeping at least one nonempty, uniquely named label. Save applies the complete configuration; Cancel discards draft edits. The first label starts new tasks.

Each task group, including General, uses the saved progress-label order. Progress subgroups and cards are lightly indented beneath clearer group headings. Compact nonempty headings and 44-point empty drop areas fit more tasks without shrinking text or controls. Heading hit regions remain at least 44 points high, with deterministic selection where expanded regions touch. Tasks retain manual order within a label. Empty task groups remain available as drop targets; an empty progress subgroup has a labelled drop area. Cards show only a thin bar; subgroup headings provide visible labels, and accessibility values retain the full label.

Task details offer a stepped slider for the configured labels. The selected label sits below the slider so long names and larger text cannot push the thumb away during a drag. One-label configurations show the label without an unusable zero-range slider. The bar expresses ordinal label position without estimating a percentage of work or time: To do is empty, In progress is halfway with the two defaults, and only actual completion fills the bar. The completion circle remains separate.

Drag within a subgroup to reorder. Drag onto another progress subgroup, including one in another task group, to apply that label and group. Drop onto a task-group heading to change group while retaining progress. General and empty groups can receive tasks. Destination highlighting and the lifted card preview the choice; group/progress assignments apply on release so source sections do not collapse and move targets under the finger. Tasks keep the same identity across all groups. A failed final save restores group, progress, and order together.

Turning progress off hides the controls while retaining labels/assignments and ordinary stored manual order. Re-enabling resumes progress ordering. Completion, archive, restore, and reopening retain the original task's marker; Copy creates an independent task at the starting label. Progress metadata does not cancel or reschedule a pending reminder. Completed remains in place; routing completion directly to Archive is a future discussion.

Successful archive/restore/delete actions now show a short opaque status message above navigation, such as **Moved to Archived**. It clears after three seconds, or six with VoiceOver, and can be tapped to dismiss. It contains no long task title, does not truncate, and does not shift the page header or navigation. Actual save errors remain visible and wrap fully.

#### Data and performance

Snapshot schema 4 stores the enable flag, ordered label UUIDs/names, and task marker references together. Older supported snapshots and legacy task arrays load with progress disabled. Renaming preserves stable references. Removing a used label reassigns its tasks to the first remaining label only when the candidate snapshot saves successfully, including completed/archived records. Unknown legacy references resolve to the starting label; corrupt configurations and unsupported newer files stay protected from overwrite.

Task/group/progress moves save atomically. Draft settings, failed writes, archive state, reminder fields, and task IDs retain their existing protection. Global presentation rows keep stable task identities across group transfers, and caches are bounded to current data, invalidated on relevant mutations, and purgeable. No per-row timer, network dependency, or continuous disk save is added. See [the measured tradeoffs](PERFORMANCE.md#v0-6-progress) for cold and repeated-read evidence; these are not phone frame-rate or battery results.

#### Validation

Validation uses Xcode 26.6 (17F113), iOS 26.5 SDK, and the iOS 17 deployment baseline. The full current-iOS UI run passed before the final spacing-only polish; focused checks repeat the affected drag, layout, accessibility, and navigation paths afterwards.

| Check | Result | Local evidence |
| --- | --- | --- |
| Full unit suite, iOS 26.5, Release | 67 passed | `/tmp/planning-progress-complete-unit.xcresult` |
| Full unit suite, iOS 17.2 | 67 passed | `/tmp/planning-progress-handoff-ios17-unit.xcresult` |
| Full UI suite, iOS 26.5 | 32 passed | `/tmp/planning-progress-final-all-ui.xcresult` |
| Compact-layout focused UI, iOS 26.5 | 10 passed | `/tmp/planning-progress-compact-current.xcresult` |
| Compact-layout focused UI, narrow iOS 17.2 | 10 passed | `/tmp/planning-progress-compact-ios17.xcresult` |
| Final device-SDK Release build, signing disabled | Passed | `/tmp/planning-progress-handoff-release.log` |
| Same-fixture Release benchmarks | Recorded cold/warm and enabled/disabled costs | [Performance evidence](PERFORMANCE.md#v0-6-progress) |

The UI coverage includes all earlier task/keyboard/group/reminder, copy/archive/delete, scroll/header, preference, and navigation cases, plus default-off progress, custom-label drafts, native editing, one-label configuration, disable/re-enable, detail sliders, cross-subgroup/group drops, and light accessibility layouts. Unit coverage additionally verifies legacy migration, corrupt/future snapshot protection, stable identities/order, cache purge, failed-save rollback, reminder continuity, and group/progress persistence.

Review caught and fixed eager transfer layout shifts, a growing label moving the slider thumb, and a coalesced first scroll event missing navigation collapse. Native UI query corrections and test scroll preparation are retained in earlier failure bundles. In the narrow cross-group test, the preparatory scroll now stops before starting the task drag instead of carrying the source beneath the compact header. No diagnostic views, logging, or accessibility overrides remain in the app.

Visual review confirmed the compact nested layout and unlabeled bars on iPhone SE, the light large-text slider with its full label below the thumb, and the short status message above stable navigation. All 34 public local documentation links/anchors resolve.

Focused commits separately cover the model, Settings, feedback, task controls, reliable scroll baseline, bounded drag/cache work, slim bars, group transfers, and layout polish. Internal planning remains local-only. Actual phone smoothness, notification delivery, haptics, and VoiceOver focus/actions remain in the checklist below.

#### Phone checklist

1. Upgrade your normal saved data: progress should be off, tasks/groups unchanged, and the initial 0.6 usability fixes retained.
2. Enable progress, rename/add/remove/reorder labels, cancel a draft first, then Save. Check that old assignments survive renaming and that the first saved label starts new tasks.
3. Move a task with the detail slider, then drag it within a subgroup, across progress subgroups, to another task-group heading, and into another group's progress subgroup. Check the bar, details, group, and saved position after relaunch. Use the detail Group selector for destinations outside the visible drag area.
4. Check empty subgroup/group targets and General. Confirm that the drop target stays still until release and that task text still opens details without completing it.
5. Disable and re-enable progress; verify retained labels/markers. Complete, reopen, archive/restore, and Copy tasks; only the circle changes completion and copies start at the starting label.
6. Use a long custom label at larger text sizes. Check that the slider stays under your finger, text wraps between words, and slim task cards have no repeated label. Try VoiceOver's progress actions and the Group selector as alternatives to dragging.
7. Archive/restore/delete a disposable task and verify the status message clears. Verify both appearances, Reduce Motion/Transparency, haptic preference, real reminder delivery, and Low Power Mode off/on on the same phone/data.

Keep all work local until owner testing. This batch does not remove Completed or define subgroup-derived numeric completion.


<a id="v0-6-0-keyboard-polish"></a>

### Keyboard and header follow-up — build 12

November 16, 2026 · Local-only; no push or PR

Opening progress-label forms produced **Invalid frame dimension (negative or non-finite)**. A captured and symbolicated runtime backtrace identified SwiftUI's `InputAccessoryBar` sizing. The keyboard-down control now sits in a shared form footer above the keyboard, avoiding that accessory path while preserving its 44-point target, accessibility label, standard keyboard suggestions, and dismissal without saving. Task and New group forms use the same control. Label names retain multiline layout and existing empty/duplicate validation, Save, and Cancel behavior.

The floating navigation's selection geometry also handles transient zero, negative, and non-finite width proposals. Ordinary tab dimensions and selection offsets remain unchanged. The compact Settings title uses its page background, removing the distinct gray material strip while retaining the large-to-compact transition and soft scroll edge.

The owner's iPhone also logged **The variant selector cell index number could not be found** while typing with the standard keyboard. The exact message is present in Apple's `TextInputUI` framework on the connected iPhone Air/iOS 26.6.1. It has not been reproduced in simulator logging; this is a separate device diagnostic, not a confirmed fix. Keep keyboard suggestions enabled and retest on the phone. No console filtering or private keyboard API is added.


#### Follow-up validation

| Check | Result | Local evidence |
| --- | --- | --- |
| Full unit suite, iOS 26.5 | 69 passed, including two new navigation geometry regressions | `/tmp/planning-label-frame-unit.xcresult` |
| Navigation unit suite, iOS 17.2 | 16 passed | `/tmp/planning-label-frame-ios17-unit.xcresult` |
| Label, group, and task keyboard scenarios, iOS 26.5 | Three passed | `/tmp/planning-keyboard-footer.xcresult` |
| Header/tab, label validation/dismissal, and large-text scenarios, iOS 26.5 | Four passed | `/tmp/planning-label-fixes-current.xcresult` |
| Same affected keyboard/header/label scenarios, narrow iOS 17.2 | Six passed | `/tmp/planning-label-fixes-ios17.xcresult` |
| Device-SDK Release build, signing disabled | Passed | `/tmp/planning-label-fixes-release.log` |
| Identical label-editor flow with live runtime logging | Four frame faults before; zero after the footer change | `/tmp/planning-label-warning-comparison.json` |

The new label test covers empty/duplicate validation, preserving text after keyboard dismissal, and cancelling without changing the parent draft. Visual inspection covered compact Settings headers in light/dark at accessibility text size, the keyboard footer on narrow iOS 17, and the light New group form on current iOS. Review confirmed no task-store, persistence, notification, drag-cache, or progress-order changes. The geometry tests fail with the previous unguarded calculation and preserve normal tab dimensions after the fix.

Phone retest: open Add label and type with the standard keyboard, dismiss/reopen input, save a custom label, and cancel another draft. Recheck task/group input and scroll Settings in both appearances. The simulator evidence resolves the reproduced frame warning; the separate variant-selector message still needs confirmation on the owner's iOS 26.6.1 device.
