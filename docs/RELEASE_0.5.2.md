# Planning 0.5.2 — Copy archived tasks

November 13, 2026 · Version 0.5.2, build 6

Archive menus and details offer **Restore**, **Copy**, and **Delete**, in that order. Copy opens the existing New Task editor with title, description, group, and reminder configuration filled in. Edit the draft and choose Add to create a new active task; the original archive stays unchanged. Reminder configuration is copied but no reminder is scheduled until the new task saves. Missing groups fall back to General.

Cancel or dismiss the editor to stay on Archive at the same scroll position. Successful Add selects Active after the editor dismisses. A failed save leaves the draft open for retry. New groups created inside the editor still save immediately, matching the existing editor behavior.

## Acceptance scenarios

Given a saved archived task, Copy opens the standard New Task editor with copied title, description, group and reminder configuration, with a fresh identity and no completion/archive state. Reminder side effects occur only after Add saves the new active task. A missing group maps to General.

Given a scrolled Archive list, cancelling or swiping down the copy editor creates no task, preserves the original archive, remains on Archived, and retains list position and compact navigation state.

Given an edited copy, successful Add saves once, dismisses the editor, and selects Active after dismissal. The original archive remains unchanged. A failed write stays in the editor without switching tabs.

Entry points: archive row actions menu and archived details, Restore / Copy / Delete order, plus VoiceOver custom Copy action. Avoid stacking competing sheets: defer presenting the copy editor until archived details finishes dismissing; defer tab change until the editor finishes dismissing.

## Validation

All 32 unit tests passed, including persisted copy identity/field preservation and missing-group fallback. Four targeted iOS 26.5 UI checks passed: Copy from details and successful navigation, Copy from the row menu and cancellation with scroll retention, archive/restore, and archived deletion. Release device-SDK build passed with signing disabled. Three narrow iPhone SE / iOS 17.2 UI checks also passed: edited Copy creation, cancellation/scroll retention, and archived delete cancellation/confirmation. Local evidence: `/tmp/planning-052-unit.xcresult`, `/tmp/planning-052-ui.xcresult`, `/tmp/planning-052-ios17.xcresult`, and `/tmp/planning-052-release.log`. Device testing should include keyboard dismissal, sheet gestures, and VoiceOver Copy actions.
