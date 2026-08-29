# Changelog

All notable user-facing changes to this project are documented here.

## [Unreleased]

### Added

- Reorder tasks by pressing, holding, and dragging them in the list.
- Collapse completed tasks into a Completed section at the bottom of the list.
- Keep the Completed section fixed to the bottom of the screen.
- Expand Completed over the lower half of the display without moving active tasks.
- Animate the Completed header into place before revealing its task rows.

### Changed

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
