# Changelog

All notable user-facing changes to this project are documented here.

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
