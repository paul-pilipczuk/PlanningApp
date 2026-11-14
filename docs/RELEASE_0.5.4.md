# Planning 0.5.4 — Consistent menus and scrolling headers

November 13, 2026 · Version 0.5.4, build 8

Completed rows replace the settings cog with an ellipsis menu containing **Edit**, **Copy**, **Archive**, and **Delete**, matching Archive’s action-menu style. Copy opens a prefilled New Task editor, preserves the completed original, selects Active after a successful Add, and retains Completed scroll position on cancellation. Saved completed-task details also offer Copy; save or cancel edits before copying. Active retains its existing control.

Completed’s swipe Remove control now uses the same native Menu presentation as Archive. Its Archive/Delete options originate from the tapped control, rather than a confirmation dialog attached to the entire page. Saved completed-task details expose direct Archive/Copy/Delete actions, like Archived details; they do not open a second chooser. Tap outside to cancel the menu. Delete still requires a separate irreversible-loss confirmation naming the task; archive still saves immediately and can be restored. VoiceOver exposes direct Archive and Delete actions without requiring a swipe.

All main pages use the shared compact frosted header and soft content edge. Settings matches its grouped background. The fade sits below the entire heading/message area, keeping feedback readable. Reduce Transparency and increased contrast use opaque surfaces; VoiceOver can retain expanded navigation while headings still respond to scrolling. Short pages do not gain artificial scroll space.

## Acceptance and review

Given only three completed tasks, swipe each row and open Remove: the menu should originate at that row’s control, with the same style as Archive. Dismissal leaves all tasks intact; Archive and Delete affect only the chosen task. Repeat with a long/scrolled list. In task details, use the matching direct action rows. Verify the final deletion confirmation still cancels safely.

Scroll Active, Completed, Archived, and Settings in both appearances: each large heading becomes the same centered compact heading, with a soft edge and stable navigation. Verify short/fitting content, larger text, preference persistence, and preserved active dragging.

Validation: all 33 unit tests and the full 18-test UI suite passed on iOS 26.5. Six focused UI checks passed on narrow iPhone SE / iOS 17.2: saved-details archive/restore, completed-copy creation, copy cancellation/scroll retention, first-three-row menus with Archive/Delete cancellation/confirmation, all-page headers in light/dark, and final-delete cancellation/confirmation. The Release device-SDK build passed with signing disabled.

Evidence: `/tmp/planning-054-final-unit.xcresult`, `/tmp/planning-054-final-ui.xcresult`, `/tmp/planning-054-se-final.xcresult`, and `/tmp/planning-054-final-release.log`. Native menu captures on the first three rows and compact headers in both appearances were visually inspected. Regression checks caught task-details menu hit-area/compatibility problems during iteration; the final direct-action detail rows pass on both OS versions.

Code review covered control anchoring, immutable deletion targets, sheet dismissal ordering, Copy identity/source preservation, unsaved-edit protection, accessibility actions, header layering, and unchanged data durability/notification contracts. Physical VoiceOver focus and phone animation feel remain device checks.

The popouts use [SwiftUI Menu](https://developer.apple.com/documentation/swiftui/menu), keeping their presentation and attachment behavior system-managed.
