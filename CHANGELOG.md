# Changelog

All notable user-facing changes to this project are documented here.

## [Unreleased]

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
