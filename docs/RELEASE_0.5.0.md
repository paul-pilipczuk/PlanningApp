# Planning 0.5.0 — Initial Archive and Settings build

November 13, 2026 · Initial build for local testing · Version 0.5.0, build 4

## What to try

Archive now holds completed tasks you want to keep. In Completed, swipe a row left and choose **Remove…**, or open its details and choose **Remove Task…**. A native chooser offers **Archive** and **Delete Permanently…**. Cancel dismisses it; on OS versions that present a popover, tapping outside may be the cancellation route. Permanent deletion always has a separate final confirmation naming the task. A full swipe never silently deletes it. The final confirmation uses the native system alert so appearance and accessibility behavior follow iOS.

Completed-task details also offer **Archive Task** directly. Save or cancel draft edits before archiving/removing from the editor; those actions operate on the saved task, and are disabled while there are unsaved changes. Creating a group in the editor still saves the group immediately, matching the previous release.

In Archived, tap a task to inspect its saved details and archive date. **Restore to Completed** preserves the task's title, description, group, reminder configuration, and original task order. Restoration leaves the task completed and does not restart reminders. To work on it again, explicitly mark it active from Completed. The visible row actions menu also offers Restore and permanent deletion. Archives are sorted newest first and retained until explicitly deleted; there is no automatic purge, bulk empty, or archive-from-active feature.

Settings keeps System/Light/Dark appearance and adds:

- **Keep navigation expanded** — keeps all four tabs visible while scrolling; headings can still become compact. VoiceOver continues to keep navigation expanded automatically.
- **Haptic feedback** — enables/disables Planning's feedback, including reordering; hardware and iPhone settings still govern availability.
- **Notifications** — reads current permission status without prompting and offers the supported route to Planning's iPhone Settings page. Status refreshes when returning to the app; reminder configuration stays in each task.
- **About** — version/build, device-local storage and archive retention information, plus a demo-session indicator.

System text size, Bold Text, contrast, Reduce Motion, and Reduce Transparency remain system preferences rather than duplicate app controls. Custom task animations now respect Reduce Motion, and the header edge uses an opaque fallback for Reduce Transparency/increased contrast. No progress sliders or 0.6.0 task-page redesign are included.

## Data continuity and failures

The local JSON snapshot moves from schema version 2 to 3 with optional archive metadata. Existing version-2 files and legacy task arrays remain supported; tasks without archive metadata remain in their current active/completed state. IDs, groups, descriptions, reminder configuration, and stored task order are preserved. Missing group references display and classify under General rather than hiding tasks.

Archive, restore, deletion, edits, completion, and group creation save a candidate snapshot atomically before publishing success. Failed writes preserve the saved data and retain the task/edit for retry. A failed reorder save restores the previous saved order. Unreadable, inconsistent, or unsupported newer files display a load issue and block overwriting the original file; **Try Again** retries loading. There is no automatic reset or destructive recovery button.

Archived tasks are excluded from ordinary completion, editing, reminder scheduling, and reorder operations. Archive/delete cancel pending and delivered reminders after the save succeeds. Reminder operations are cancelled/ordered when a task changes so a delayed permission/scheduling operation cannot resurrect an archived task's reminder.

Storage is still local and synchronous, preserving the established serialized-write contract. A general asynchronous storage redesign and native session undo are deferred. Persistent Restore is the archive recovery route. Permanent deletion removes the app's record; it does not claim secure erasure of device storage or deletion from OS backups.

## Demo and device test checklist

Use the **PlanningApp Demo** Xcode scheme for 24 active, 24 completed, and 12 archived sample tasks. Demo task changes are memory-only and reset on relaunch; real saved tasks and reminders remain isolated. App appearance/preferences persist and are shared with the ordinary scheme.

1. In Completed, open a task's details, choose Remove, then cancel. Repeat and Archive it.
2. Open the archived task, inspect its fields/date, and restore it. Confirm that it returns to Completed with its group intact.
3. Repeat removal and select permanent deletion. Cancel the final confirmation first, then repeat and confirm. Verify that the task is absent from both Completed and Archived.
4. Try the direct Archive button and the Archive row actions menu. Change a task field and check that saving/cancelling is required before removal.
5. Turn on Keep navigation expanded, scroll Completed/Archived, and verify compact headings with the full bar still visible. Relaunch and confirm the preference persists.
6. Toggle haptics and reorder an active task on a physical phone. Check light/dark appearance, larger text, VoiceOver actions/focus, and reduced-motion/transparency behavior.
7. Inspect notification status; open iPhone Settings, change notification permission if desired, and return. With real tasks, verify reminder cancellation after completion/archive/delete and no reminder after Restore to Completed.
8. With the normal scheme, verify existing tasks survive the upgrade and changes survive relaunch. Use disposable test data for permanent-deletion experiments.

## Validation

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
