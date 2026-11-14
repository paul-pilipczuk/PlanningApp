# Changelog

All notable user-facing changes to this project are documented here.

## [0.5.4] - 2026-11-13

- Add a Completed ellipsis menu with Edit, Copy, Archive, and Delete; support copying completed tasks into new active variations.
- Match Completed removal popouts to Archive’s native control-anchored menus; use direct action rows in task details.
- Keep separate permanent-delete confirmation and direct assistive-technology Archive/Delete actions.
- Use consistent compact frosted headers and page-matched soft edges across every tab.
- Keep feedback outside the scroll fade and allow header transitions while VoiceOver keeps navigation expanded.

## [0.5.3] - 2026-11-13

- Condense Settings with sentence-case headings, consistent spacing, and fewer detached summaries.
- Keep storage/retention information inside About and concise control guidance in accessibility hints.
- Combine app version and build in one row; preserve appearance, navigation, haptic, and notification behavior.
- Stack Settings labels and values when space is limited, preventing split words at larger text sizes.

## [0.5.2] - 2026-11-13

- Add Copy between Restore and Delete in archived task actions and details.
- Prefill a new task with the archived task's fields, leaving the original unchanged.
- Select Active after successful creation; cancellation retains Archive and its scroll position.

## [0.5.1] - 2026-11-13

- Shorten task actions to Restore, Archive, Remove, and Delete without trailing punctuation.
- Keep permanent-delete warnings in the confirmation message, avoiding long wrapping button titles.
- Document shared interface wording, accessibility, and layout conventions.

## [0.5.0] - 2026-11-13

### Added

- Archive completed tasks, inspect saved archive details, and restore tasks to Completed.
- Offer Archive or permanent deletion from Completed removal actions, with a final confirmation for permanent deletion.
- Add persistent navigation-visibility and app haptic-feedback preferences.
- Show notification permission status, a supported iPhone Settings link, and app build/retention information.
- Add 12 archived demo tasks and archive, migration, failed-save, preference, and UI regression tests.

### Changed

- Preserve saved data on failed mutations and protect unreadable/unsupported files from being overwritten.
- Exclude archived tasks from editing, completion, reordering, and notification scheduling.
- Keep failed task edits open and require saving/cancelling draft edits before removal.
- Honor Reduce Motion for custom task animations and opaque header treatment for reduced transparency/increased contrast.
- Migrate local snapshots additively to schema version 3 while retaining version-2 and legacy-array loading.

## [0.4.2] - 2026-11-11

### Fixed

- Hide page scroll indicators, removing the visible scroll gutter.
- Use consistent large-to-compact heading alignment and typography across every tab, with Active’s add bubble independent of title layout.
- Soften scrolling content beneath compact headings with a shallow material fade and a Reduce Transparency fallback.
- Give Archived the same scroll-observation path as other pages when its content needs to scroll.

### Kept

- Stable floating navigation, circular add control, task gestures, and the existing performance optimizations.

## [0.4.1] - 2026-11-11

### Fixed

- Restore large headings transitioning to compact titles while scrolling, and expanding near the top.
- Restore the circular Add task button, aligned with Active in both heading sizes.
- Keep floating navigation anchored during tab changes; animate the selection highlight without moving or warping the entire bar.
- Connect Settings to the same scroll-collapse behavior as Active and Completed when its content overflows.
- Include bottom content padding in iOS 17 scroll measurements for consistent collapse near the end of a list.

### Kept

- The 0.4.0 performance changes, task gestures, grouping, reminders, persistence, and light/dark appearance choices.

## [0.4.0] - 2026-11-11

### Added

- Four floating navigation destinations: Active, Completed, Archived, and Settings.
- Downward scrolling collapses navigation into a circle at the bottom left; tapping it expands the bar.
- Archived placeholder with “Coming soon”.
- Persistent System, Light, and Dark appearance settings, with Dark as the initial default.
- An isolated Debug demo scheme with 24 active and 24 completed JSON sample tasks.
- Unit and UI test targets for navigation, sample-data isolation, appearance, and task flows.
- A visible Add task toolbar action alongside blank-space creation.

### Changed

- Reduce scrolling-related root/list updates and task-array animation comparisons.
- Build grouped active lists in one pass, with a repeatable large-data benchmark and ordering regression tests.

- Animate the selected highlight and screen changes consistently across all four tabs, including nonadjacent selections.
- Align the Add task plus button with the large Active heading.
- Let tasks use the space behind the floating bar, with end padding to reveal the last task.
- Allow normal completed-row swipes to scroll the list and collapse navigation.

- Replace the Completed drawer with its own full list destination.
- Preserve the current task scrolling and drag interactions for a later UX iteration.
- Adapt the existing rounded task rows to both light and dark appearance.
- Keep the bottom inset fixed as navigation collapses and support Reduce Motion, Reduce Transparency, and VoiceOver navigation.
- Require Xcode 26 to compile the guarded glass implementation; retain iOS 17 as the deployment target.

## [Unreleased prior foundation work]

### Added

- Add task descriptions and local named task groups.
- Create a group directly from the new-task or task-details editor.
- Open a unified task-details editor by tapping a task or its cog button.
- Delete tasks from task details or by swiping left and choosing Delete.
- Organize active tasks beneath group headings, with ungrouped tasks under General.
- Preserve existing saved tasks through a backward-compatible on-device data migration.
- Reorder tasks by pressing, holding, and dragging them in the list.
- Collapse completed tasks into a Completed section at the bottom of the list.
- Keep the Completed section fixed to the bottom of the screen.
- Expand Completed over the lower half of the display without moving active tasks.
- Animate the Completed header into place before revealing its task rows.

### Changed

- Make a task’s primary tap area complete it; long-pressing opens task details and dragging reorders it.
- Keep drag reordering within a task's current group.
- Rename the user-facing app title to Planning.
- Start a new reminder’s time picker at the current time.
- Remove the visible drag placeholder while reordering tasks.
- Use a large title style for the Completed section header.
- Remove the Completed section divider and raise the sticky drawer slightly.

## [0.1.0] - 2026-08-29

### Added

- Initial offline SwiftUI planning app.
- Create, rename, and complete tasks.
- Local daily and weekly task reminders.
- Optional “repeat until done” reminders.
- On-device JSON task persistence.
