# Testing Methodology

## Purpose

Planning is a learning project, but it should remain dependable as it grows. Testing protects the task behaviors people rely on: creating and editing tasks, completing them, grouping them, reordering them, deleting them, and scheduling reminders.

This project uses a tests-first approach for new behavior. A feature is not considered complete merely because it works during a manual run; its expected behavior should be captured in automated tests and checked on a device where interaction or notification behavior matters.

## Development approach

### TDD for logic and state

Use test-driven development for deterministic code such as models, persistence, ordering, grouping, and notification-scheduling decisions.

1. Write a failing test that describes one small rule.
2. Add the smallest production change that makes it pass.
3. Refactor only while the test remains green.
4. Run the relevant test suite before committing.

Examples include moving a task only inside its group, cancelling a reminder when a task is completed, and safely loading tasks saved by an older app version.

### BDD for user-facing behavior

Describe a feature’s user outcome in Given/When/Then language before implementation. Turn stable, automatable scenarios into unit or UI tests; retain device-only cases as a manual release checklist.

Example:

```text
Given an active task in General
When the user drags it past another General task and releases
Then the task appears after that task
And the new order is retained after restarting the app
```

BDD scenarios should focus on observable behavior rather than SwiftUI implementation details.

## Test layers

### Unit tests

Use unit tests as the default layer. Cover:

- `TaskItem`, groups, and reminder defaults.
- `TaskStore` creation, edits, completion, deletion, and group-local ordering.
- JSON encoding, loading, and migration from earlier saved task formats.
- Notification request construction and cancellation decisions, with the notification service injected or mocked.

Unit tests should avoid the real Application Support directory and real notification center. Use temporary storage and test doubles so results are repeatable.

### UI tests

Use UI tests for critical flows that involve SwiftUI presentation or gesture wiring:

- Creating a task with a description and group.
- Completing a task through the primary row tap.
- Opening task details through a stationary long press or cog button.
- Revealing task deletion by swiping left and confirming deletion.
- Switching between Active, Completed, Archived, and Settings.
- Collapsing the floating bar on actual downward scroll and expanding its leading circle.
- Changing appearance and retaining the selection after relaunch.

Keep gesture-heavy UI tests focused and resilient. The detailed feel of reordering is also verified manually on a physical device.

### Manual device checks

Run these for each release candidate on a real iPhone:

- Notification permission, scheduling time, and delivery.
- Drag smoothness, cancellation, and ordering persistence.
- Dynamic Type, VoiceOver labels and actions, Reduce Motion, and dark appearance.
- First launch, upgrade with existing saved tasks, and relaunch after force quitting.

## Release workflow

Before beginning a feature or release:

1. Write BDD acceptance scenarios for the intended behavior.
2. Identify the unit-testable rules and write failing tests for them.
3. Implement in small increments until the tests pass.
4. Add a UI test when the behavior depends on presentation or input wiring.

Before shipping a release:

1. Run all automated tests in Xcode or with `xcodebuild test`.
2. Run the relevant manual device checklist.
3. Record user-visible changes in `CHANGELOG.md`.
4. Treat any regression found during testing as a new scenario and automated test where practical.

## Test quality rules

- One test should prove one behavior.
- Name tests after the behavior and expected result.
- Prefer public behavior over private implementation details.
- Keep tests deterministic; do not depend on timing, the network, the current calendar date, or existing device data unless those are intentionally controlled.
- Fix a regression with a failing test first when practical, then make the fix.

## Starting point

The first test suite should establish seams around `TaskStore` persistence and `NotificationManager`, then cover task lifecycle and group-local reorder rules. UI tests can follow for the core task flows once the logic has a stable automated foundation.

## 0.4.0 automated coverage

`PlanningAppTests` covers collapse thresholds, jitter, overscroll, explicit expansion, tab resets, invalid measurements, fixture integrity, memory-only demo edits, and persisted completion with temporary storage. `PlanningAppUITests` covers all destinations, scroll collapse/expansion, appearance persistence, completion/reopening, task details, and task creation presentation. UI tests launch with `-sample-data` and use the list margin to preserve the current row-drag interaction.

See [the milestone notes](docs/RELEASE_0.4.0.md) for Given/When/Then scenarios, exact validation evidence, and remaining device checks. Tests do not establish comprehensive foundation readiness or verify real notification delivery.

The separate performance follow-up adds a scroll-publication regression, grouped ordering/completion coverage, and a 10,000-task construction benchmark. Timings are comparative evidence, not an absolute CI threshold or a substitute for phone profiling. [Performance notes](docs/PERFORMANCE.md) describe the fixture, configuration, and device comparison.

## 0.4.1 appearance regressions

[The 0.4.1 notes](docs/RELEASE_0.4.1.md) record restored compact headings, the circular inline add control, stable floating-bar bounds during tab changes, and collapse on scrollable Settings content. Tests exercise Completed with the full demo fixture and Settings at larger accessibility text sizes; short/static pages intentionally keep navigation expanded. Heading state is tested for hysteresis and distinct publication so the prior scroll-performance work remains in place.

## 0.4.2 visual polish

[The 0.4.2 notes](docs/RELEASE_0.4.2.md) record consistent compact heading alignment, the shared Archived scroll path, hidden page scroll indicators, and the material edge. The UI suite captures Active/Completed/Settings compact headers and checks centering, restoration, navigation bounds, and Archived's fitting-content behavior. Visual inspection in light and dark appearance checks the soft edge and hidden indicators; the effect has no touch target or additional scroll-state publication.

## 0.5.0 archive and settings

[The 0.5.0 release notes](docs/RELEASE_0.5.0.md) record initial-build evidence and the device checklist. Unit coverage includes archive/restore persistence and field preservation, legacy migration, newest-first archives, stale archived-task operations, failed-write rollback, unreadable/future/inconsistent file protection, reminder cancellation, and preference persistence. Writes use temporary files and injected failure/notification seams.

UI coverage exercises the completed-task removal chooser, cancellation, archiving, restoration, final deletion confirmation, deletion from archived details, navigation preference persistence, and existing task/navigation/scroll gestures. Capture permanent-delete alerts after their presentation transition for light/dark visual review; an intermediate frame can make the system material appear unusually transparent. Native system alert styling remains in use.

UI runs use memory-only fixtures plus a Debug-only preference suite (`-ui-testing`). `-reset-test-preferences` clears only that suite at test setup; remove the reset argument before relaunch persistence checks. Demo and ordinary app preferences are unaffected. If SpringBoard reports a preflight Busy error before the app launches, record it as infrastructure failure and repeat UI-only on an isolated simulator; do not interpret it as an exercised app interaction. Unit and UI suites can be run separately. Actual VoiceOver focus, physical haptics, reminder delivery, and phone animation feel remain device checks.

## 0.5.2 archive copies

A copy must preserve editable fields while creating an independent active identity only when saved. Unit tests cover archive preservation across relaunch and fallback from a missing group. UI tests cover both entry points, editing/adding with navigation to Active after dismissal, and cancelling from a scrolled Archive list with row-position and compact-navigation assertions. Existing archive/restore/delete scenarios remain regression checks.

## 0.5.4 menus, completed copies, and shared headers

Use the Debug-only `-sample-data -short-completed-data` fixture to verify the first three Completed removal controls without artificial overflow. Tests open each native menu, dismiss it without changes, archive a selected row, and cancel/confirm deletion from Completed’s ellipsis menu. Saved details use direct Archive/Copy/Delete rows; destructive confirmation still occurs after the editor dismisses. Completed Copy tests verify an independent active task and cancellation with retained scroll position. Compare shared compact headers on every tab in light/dark appearance and repeat on a narrow iOS 17 phone.
