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
