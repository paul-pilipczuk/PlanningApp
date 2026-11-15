# Planning 0.5 — Archive, Settings, and performance

Release history for the 0.5 series, grouped by patch version. The latest documented patch is [0.5.5](#v0-5-5). Earlier sections describe behavior and validation at that release; later patches supersede those details.

## Versions

- [0.5.0 — Initial Archive and Settings build](#v0-5-0)
- [0.5.1 — Simple actions](#v0-5-1)
- [0.5.2 — Copy archived tasks](#v0-5-2)
- [0.5.3 — Condensed Settings](#v0-5-3)
- [0.5.4 — Consistent menus and scrolling headers](#v0-5-4)
- [0.5.5 — Lightweight task updates](#v0-5-5)

<a id="v0-5-0"></a>

## 0.5.0 — Initial Archive and Settings build

November 13, 2026 · Initial build for local testing · Version 0.5.0, build 4

<a id="v0-5-0-what-to-try"></a>

### What to try

Archive now holds completed tasks you want to keep. In Completed, swipe a row left and choose **Remove…**, or open its details and choose **Remove Task…**. A native chooser offers **Archive** and **Delete Permanently…**. Cancel dismisses it; on OS versions that present a popover, tapping outside may be the cancellation route. Permanent deletion always has a separate final confirmation naming the task. A full swipe never silently deletes it. The final confirmation uses the native system alert so appearance and accessibility behavior follow iOS.

Completed-task details also offer **Archive Task** directly. Save or cancel draft edits before archiving/removing from the editor; those actions operate on the saved task, and are disabled while there are unsaved changes. Creating a group in the editor still saves the group immediately, matching the previous release.

In Archived, tap a task to inspect its saved details and archive date. **Restore to Completed** preserves the task's title, description, group, reminder configuration, and original task order. Restoration leaves the task completed and does not restart reminders. To work on it again, explicitly mark it active from Completed. The visible row actions menu also offers Restore and permanent deletion. Archives are sorted newest first and retained until explicitly deleted; there is no automatic purge, bulk empty, or archive-from-active feature.

Settings keeps System/Light/Dark appearance and adds:

- **Keep navigation expanded** — keeps all four tabs visible while scrolling; headings can still become compact. VoiceOver continues to keep navigation expanded automatically.
- **Haptic feedback** — enables/disables Planning's feedback, including reordering; hardware and iPhone settings still govern availability.
- **Notifications** — reads current permission status without prompting and offers the supported route to Planning's iPhone Settings page. Status refreshes when returning to the app; reminder configuration stays in each task.
- **About** — version/build, device-local storage and archive retention information, plus a demo-session indicator.

System text size, Bold Text, contrast, Reduce Motion, and Reduce Transparency remain system preferences rather than duplicate app controls. Custom task animations now respect Reduce Motion, and the header edge uses an opaque fallback for Reduce Transparency/increased contrast. No progress sliders or 0.6.0 task-page redesign are included.

<a id="v0-5-0-data-continuity-and-failures"></a>

### Data continuity and failures

The local JSON snapshot moves from schema version 2 to 3 with optional archive metadata. Existing version-2 files and legacy task arrays remain supported; tasks without archive metadata remain in their current active/completed state. IDs, groups, descriptions, reminder configuration, and stored task order are preserved. Missing group references display and classify under General rather than hiding tasks.

Archive, restore, deletion, edits, completion, and group creation save a candidate snapshot atomically before publishing success. Failed writes preserve the saved data and retain the task/edit for retry. A failed reorder save restores the previous saved order. Unreadable, inconsistent, or unsupported newer files display a load issue and block overwriting the original file; **Try Again** retries loading. There is no automatic reset or destructive recovery button.

Archived tasks are excluded from ordinary completion, editing, reminder scheduling, and reorder operations. Archive/delete cancel pending and delivered reminders after the save succeeds. Reminder operations are cancelled/ordered when a task changes so a delayed permission/scheduling operation cannot resurrect an archived task's reminder.

Storage is still local and synchronous, preserving the established serialized-write contract. A general asynchronous storage redesign and native session undo are deferred. Persistent Restore is the archive recovery route. Permanent deletion removes the app's record; it does not claim secure erasure of device storage or deletion from OS backups.

<a id="v0-5-0-demo-and-device-test-checklist"></a>

### Demo and device test checklist

Use the **PlanningApp Demo** Xcode scheme for 24 active, 24 completed, and 12 archived sample tasks. Demo task changes are memory-only and reset on relaunch; real saved tasks and reminders remain isolated. App appearance/preferences persist and are shared with the ordinary scheme.

1. In Completed, open a task's details, choose Remove, then cancel. Repeat and Archive it.
2. Open the archived task, inspect its fields/date, and restore it. Confirm that it returns to Completed with its group intact.
3. Repeat removal and select permanent deletion. Cancel the final confirmation first, then repeat and confirm. Verify that the task is absent from both Completed and Archived.
4. Try the direct Archive button and the Archive row actions menu. Change a task field and check that saving/cancelling is required before removal.
5. Turn on Keep navigation expanded, scroll Completed/Archived, and verify compact headings with the full bar still visible. Relaunch and confirm the preference persists.
6. Toggle haptics and reorder an active task on a physical phone. Check light/dark appearance, larger text, VoiceOver actions/focus, and reduced-motion/transparency behavior.
7. Inspect notification status; open iPhone Settings, change notification permission if desired, and return. With real tasks, verify reminder cancellation after completion/archive/delete and no reminder after Restore to Completed.
8. With the normal scheme, verify existing tasks survive the upgrade and changes survive relaunch. Use disposable test data for permanent-deletion experiments.

<a id="v0-5-0-validation"></a>

### Validation

Validation completed November 13, 2026 with Xcode 26.6 (17F113), iOS 26.5 SDK, and iPhone simulators. Core changes are in `0232dab`; Archive/Settings UI and version bump are in `d23875e`.

| Check | Result | Local evidence |
| --- | --- | --- |
| Complete unit suite, iOS 26.5 | 30 passed, zero failures | `/tmp/planning-050-unit-final.xcresult` |
| Complete UI suite, iOS 26.5 | 11 passed, zero failures | `/tmp/planning-050-native-ui.xcresult` |
| Focused UI compatibility, iOS 17.2 | 5 passed, zero failures | `/tmp/planning-050-ios17-final.xcresult` |
| Release device-SDK build, code signing disabled | Passed | `/tmp/planning-050-release-final.log` |
| Settled native deletion alerts, light/dark | Screenshots inspected; readable surfaces in both appearances | Attachments in the final iOS 26 UI result bundle |

Unit and UI suites ran separately. The five iOS 17 checks cover archive/restore, deletion cancellation/confirmation from Completed and archived details, navigation preference persistence, and overflow scrolling in Settings/Archived. The iOS 26 suite additionally retains task completion, active reordering, task editor presentation, four destinations, skipping tabs with stable navigation bounds, and heading/collapse regressions.

Some earlier runs hit a SpringBoard preflight Busy launch error before app launch; the final isolated UI-only run passed every case. Regression testing also caught a selected-task lifetime issue in deletion presentation; confirmations retain the selected task while presentation bindings change. An earlier screenshot captured the native deletion confirmation during its presentation transition, making its surface appear unusually transparent. Keep the system alert; assess the settled presentation in light/dark appearance and with accessibility settings rather than judging that transitional frame. The final settled screenshots show a frosted light surface and a dark surface with clear text and distinct actions; system accessibility behavior still needs the device checks above.

UI tests use a separate Debug-only preference suite and memory-only task fixtures. Normal/Demo preferences are unaffected by test resets. Physical notification delivery, hardware haptics, actual VoiceOver focus, and phone gesture/animation feel remain local tests; this initial build is not a claim of complete accessibility or foundation readiness.

<a id="v0-5-1"></a>

## 0.5.1 — Simple actions

November 13, 2026 · Version 0.5.1, build 5

Task actions use short verbs without trailing punctuation: Restore, Archive, Remove, and Delete. The same wording appears in archived details, archive menus, completed removal choices, editors, and delete confirmations. Restore still returns a task to Completed. Delete still requires a native confirmation that names the task and explains irreversible removal.

Given an archived task, opening its actions or details shows short complete words. Cancelling deletion retains the task. Confirming deletion removes only that task. Archiving and restoration retain their existing behavior.

The new [interface conventions](UX_CONVENTIONS.md) make concise action labels and avoiding split words repository rules while retaining Dynamic Type and 44-point targets. Test narrow phones and larger text sizes locally.

Validation: three targeted UI regressions passed on iOS 26.5 (archive/restore, Completed delete cancel/confirm, and Archived delete cancel/confirm); Release device-SDK build passed with code signing disabled. Evidence: `/tmp/planning-051-ui-clean.xcresult` and `/tmp/planning-051-release.log`. The first reused simulator failed test-runner preflight with SpringBoard Busy before executing tests; the clean simulator run passed.

<a id="v0-5-2"></a>

## 0.5.2 — Copy archived tasks

November 13, 2026 · Version 0.5.2, build 6

Archive menus and details offer **Restore**, **Copy**, and **Delete**, in that order. Copy opens the existing New Task editor with title, description, group, and reminder configuration filled in. Edit the draft and choose Add to create a new active task; the original archive stays unchanged. Reminder configuration is copied but no reminder is scheduled until the new task saves. Missing groups fall back to General.

Cancel or dismiss the editor to stay on Archive at the same scroll position. Successful Add selects Active after the editor dismisses. A failed save leaves the draft open for retry. New groups created inside the editor still save immediately, matching the existing editor behavior.

<a id="v0-5-2-acceptance-scenarios"></a>

### Acceptance scenarios

Given a saved archived task, Copy opens the standard New Task editor with copied title, description, group and reminder configuration, with a fresh identity and no completion/archive state. Reminder side effects occur only after Add saves the new active task. A missing group maps to General.

Given a scrolled Archive list, cancelling or swiping down the copy editor creates no task, preserves the original archive, remains on Archived, and retains list position and compact navigation state.

Given an edited copy, successful Add saves once, dismisses the editor, and selects Active after dismissal. The original archive remains unchanged. A failed write stays in the editor without switching tabs.

Entry points: archive row actions menu and archived details, Restore / Copy / Delete order, plus VoiceOver custom Copy action. Avoid stacking competing sheets: defer presenting the copy editor until archived details finishes dismissing; defer tab change until the editor finishes dismissing.

<a id="v0-5-2-validation"></a>

### Validation

All 32 unit tests passed, including persisted copy identity/field preservation and missing-group fallback. Four targeted iOS 26.5 UI checks passed: Copy from details and successful navigation, Copy from the row menu and cancellation with scroll retention, archive/restore, and archived deletion. Release device-SDK build passed with signing disabled. Three narrow iPhone SE / iOS 17.2 UI checks also passed: edited Copy creation, cancellation/scroll retention, and archived delete cancellation/confirmation. Local evidence: `/tmp/planning-052-unit.xcresult`, `/tmp/planning-052-ui.xcresult`, `/tmp/planning-052-ios17.xcresult`, and `/tmp/planning-052-release.log`. Device testing should include keyboard dismissal, sheet gestures, and VoiceOver Copy actions.

<a id="v0-5-3"></a>

## 0.5.3 — Condensed Settings

November 13, 2026 · Version 0.5.3, build 7

Settings uses sentence-case section headings, consistent card spacing, and the same 16-point page margins as task lists. Detached explanatory summaries are removed. About keeps a concise storage/retention note inside its card and combines version/build into one row. The Notifications section has a short Settings action with a full accessibility label. Label/value rows switch to a vertical layout when there is insufficient room to keep their words intact.

System appearance remains an option, and iPhone accessibility settings still apply automatically. VoiceOver hints retain useful guidance about the navigation/haptic controls and notification permission. Preferences, permission refresh on return, notification opt-in, and task reminders retain their existing behavior.

Given Settings in either appearance or larger text, controls remain legible and reachable without uppercase headers or detached paragraphs. Changing navigation/haptics and relaunching retains both independent choices. Changing appearance still applies throughout the app. Overflow scrolling still compacts the heading and collapses navigation when permitted.

Initial validation passed three focused iOS 26.5 UI checks (appearance/relaunch, independent navigation/haptic persistence, and large-text overflow scrolling) and the Release device-SDK build. Visual review caught a pre-existing horizontal label/value issue that split “Permission” at the largest text size; this candidate adds an adaptive stacked layout and a readability regression test. After the fix, the largest-text readability test and the independent navigation/haptic persistence regression both passed on iOS 26.5; the final Release build also passed. The corrected largest-text screenshot was inspected and keeps Permission and its value intact. Local evidence: `/tmp/planning-053-ui.xcresult`, `/tmp/planning-053-a11y.xcresult`, and `/tmp/planning-053-release-final.log`.

The owner tested the local 0.5.3 build and approved it on November 13 before the branch was pushed. 0.5.4 follows this release. Physical VoiceOver and hardware haptics remain device checks.

Code review checked both layout commits for preference binding/key changes, permission prompting, notification refresh on return, Dynamic Type, semantic colors, and hit targets. The settings behavior remains intact; the visual review finding above is fixed before local handoff.

<a id="v0-5-4"></a>

## 0.5.4 — Consistent menus and scrolling headers

November 13, 2026 · Version 0.5.4, build 8

Completed rows replace the settings cog with an ellipsis menu containing **Edit**, **Copy**, **Archive**, and **Delete**, matching Archive’s action-menu style. Copy opens a prefilled New Task editor, preserves the completed original, selects Active after a successful Add, and retains Completed scroll position on cancellation. Saved completed-task details also offer Copy; save or cancel edits before copying. Active retains its existing control.

Completed’s swipe Remove control now uses the same native Menu presentation as Archive. Its Archive/Delete options originate from the tapped control, rather than a confirmation dialog attached to the entire page. Saved completed-task details expose direct Archive/Copy/Delete actions, like Archived details; they do not open a second chooser. Tap outside to cancel the menu. Delete still requires a separate irreversible-loss confirmation naming the task; archive still saves immediately and can be restored. VoiceOver exposes direct Archive and Delete actions without requiring a swipe.

All main pages use the shared compact frosted header and soft content edge. Settings matches its grouped background. The fade sits below the entire heading/message area, keeping feedback readable. Reduce Transparency and increased contrast use opaque surfaces; VoiceOver can retain expanded navigation while headings still respond to scrolling. Short pages do not gain artificial scroll space.

<a id="v0-5-4-acceptance-and-review"></a>

### Acceptance and review

Given only three completed tasks, swipe each row and open Remove: the menu should originate at that row’s control, with the same style as Archive. Dismissal leaves all tasks intact; Archive and Delete affect only the chosen task. Repeat with a long/scrolled list. In task details, use the matching direct action rows. Verify the final deletion confirmation still cancels safely.

Scroll Active, Completed, Archived, and Settings in both appearances: each large heading becomes the same centered compact heading, with a soft edge and stable navigation. Verify short/fitting content, larger text, preference persistence, and preserved active dragging.

Validation: all 33 unit tests and the full 18-test UI suite passed on iOS 26.5. Six focused UI checks passed on narrow iPhone SE / iOS 17.2: saved-details archive/restore, completed-copy creation, copy cancellation/scroll retention, first-three-row menus with Archive/Delete cancellation/confirmation, all-page headers in light/dark, and final-delete cancellation/confirmation. The Release device-SDK build passed with signing disabled.

Evidence: `/tmp/planning-054-final-unit.xcresult`, `/tmp/planning-054-final-ui.xcresult`, `/tmp/planning-054-se-final.xcresult`, and `/tmp/planning-054-final-release.log`. Native menu captures on the first three rows and compact headers in both appearances were visually inspected. Regression checks caught task-details menu hit-area/compatibility problems during iteration; the final direct-action detail rows pass on both OS versions.

Code review covered control anchoring, immutable deletion targets, sheet dismissal ordering, Copy identity/source preservation, unsaved-edit protection, accessibility actions, header layering, and unchanged data durability/notification contracts. Physical VoiceOver focus and phone animation feel remain device checks.

The popouts use [SwiftUI Menu](https://developer.apple.com/documentation/swiftui/menu), keeping their presentation and attachment behavior system-managed.

<a id="v0-5-5"></a>

## 0.5.5 — Lightweight task updates

November 13, 2026 · Version 0.5.5, build 9

Planning avoids rebuilding filtered, sorted, and grouped task collections during repeated view updates. Derived collections are lazy, bounded to current data, invalidated after mutations, and discarded on memory warnings. Dragging queries the active task’s group rather than filtering the entire store for every movement. Task animation checks use a revision token rather than full-array equality.

Appearance, task gestures, data schema, atomic saving, failure recovery, reminders, Archive/Completed Copy flows, and system accessibility settings retain their current behavior. No new runtime packages, timers, or services are introduced. Cold collection work and synchronous persistence remain; this patch targets redundant repeated work.

Lightweight, responsive operation is now an explicit standing requirement in README, AGENTS.md, [performance guidance](PERFORMANCE.md), and [interface conventions](UX_CONVENTIONS.md), including older supported iPhones and recorded Low Power Mode comparisons.

<a id="v0-5-5-measurement-and-validation"></a>

### Measurement and validation

The same Release simulator benchmark with 10,000 tasks measured 50 warmed collection reads at 1.271 seconds before and about 0.27 milliseconds after optimization. Five cold stores/read passes stayed near 0.13 seconds. Peak physical footprints were similar in these runs; caching has a bounded memory cost and an explicit purge path. See [the measurement protocol and limitations](PERFORMANCE.md#beforeafter-measurement).

All 39 unit tests and the full 18-test UI suite passed on iOS 26.5. All 39 unit tests also passed on iOS 17.2, together with six focused narrow iPhone SE UI checks for drag/reorder, scroll collapse/expansion, Completed Copy, copy cancellation/scroll retention, short-list menus/deletion, and archive/restore. The final Release device-SDK build passed with signing disabled.

Evidence: `/tmp/planning-055-unit.xcresult`, `/tmp/planning-055-ui.xcresult`, `/tmp/planning-055-ios17-unit.xcresult`, `/tmp/planning-055-ios17-ui.xcresult`, and `/tmp/planning-055-release-final.log`, plus the before/after benchmark bundles linked above.

Code review checked every mutation/reload/rollback invalidation path, raw group membership, archive ordering, cache bounds and purge, publication behavior, animation revision, and unchanged persistence/reminder semantics. A review correction avoids retaining arbitrary empty group queries. Warm-cache regressions verify current data after lifecycle changes, group reload, rollback, and purge. Physical-device SwiftUI/Time Profiler traces, frame pacing, energy use, and Low Power Mode behavior still require the phone comparison; simulator SE checks validate layout/compatibility, not that phone’s CPU speed.

<a id="v0-5-5-device-comparison"></a>

### Device comparison

1. Use identical saved plans, phone model, iOS, appearance, thermal conditions, and Release configuration for 0.5.4 and 0.5.5. The Debug-only Demo fixture is not loaded in Release.
2. Compare tab changes, scrolling every page, dragging within a group, opening/editing details, completing/reopening, archive/restore, and Copy/cancellation.
3. Repeat with Low Power Mode off and on, recording the condition. Keep accessibility accommodations enabled when checking their performance.
4. Profile with the SwiftUI and Time Profiler instruments if a hitch remains, and record the action, data size, and trace. Verify save/relaunch and failure behavior alongside smoothness.
