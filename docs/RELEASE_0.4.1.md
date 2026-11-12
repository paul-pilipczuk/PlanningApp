# Planning 0.4.1 — Heading and navigation polish

November 11, 2026. Appearance, animation, and scroll-observation fixes following the 0.4.0 UX/performance commits. Existing task gestures, one-pass grouping, measurement caching, distinct state publication, data format, reminders, and appearance preferences are retained.

## Behavior

Large headings crossfade into smaller centered titles once content has scrolled 36 points, and return to the large leading title within four points of the top. Separate thresholds prevent repeated transitions as the header changes height. Expanding the bottom bar does not enlarge a heading while its page is still scrolled. Switching tabs resets the heading for the new page. The circular 44-point Add task control stays on the Active heading line in either size and uses the same glass/material surface as navigation.

The bottom bar is anchored outside the changing page layout. Tab-switch animations are scoped to the selected highlight and content fade; the whole bar no longer receives the tab animation or an interactive glass press deformation. Collapse/expansion animation remains available. Late scroll callbacks from a departing tab are ignored.

| Page | Scroll/collapse behavior |
| --- | --- |
| Active | Actual downward scroll collapses navigation. The existing active-row drag remains; use the margin to scroll. |
| Completed | Swiping over rows scrolls and collapses navigation when enough content exists. The demo provides 24 completed tasks. |
| Settings | Uses the shared scroll observer and familiar grouped cards on iOS 17+. Scrolling collapses navigation when the content overflows, including at larger text sizes. |
| Archived | A static Coming soon screen; no scrolling or collapse is expected. |
| Any short page | Rubber-banding without actual scrollable range keeps navigation expanded. |

Previously Settings had no scroll callback. Its few controls also often fit without scrolling, so a stationary bar there can be expected. Completed already had scroll tracking; these checks exercise it with enough fixture tasks rather than assuming a short real list can scroll. End padding now lives inside measured content on both scroll API paths, avoiding an understated scroll range on iOS 17.

## Acceptance and validation

Automated checks cover heading compaction/restoration on both task lists, inline Add task alignment, stable navigation bounds across nonadjacent tab changes, completed-row scrolling, Settings scrolling with large accessibility text, the non-scrolling Archived placeholder, and publication only on heading threshold changes. Existing task lifecycle, drag, appearance, grouping, and performance tests remain included.

An initial run could not launch the app because the existing iOS 26 simulator reported a SpringBoard preflight Busy error. A fresh isolated simulator is used for the final validation. Final validation:

| Check | Result |
| --- | --- |
| Fresh iPhone 17 Pro, iOS 26.5 Simulator | 27 tests passed: 20 unit and seven UI tests. |
| Fresh iPhone 15 Pro, iOS 17.2 Simulator | Three focused UI tests passed: task-list headings/collapse, Settings/Archived scroll behavior, and stable bar bounds across tab changes. |
| Release build, iPhone device SDK | Passed with signing disabled. |
| Built metadata | Version 0.4.1, build 2. |
| Visual inspection | Inspected compact Active heading/add bubble and Settings screenshots. |
| Source whitespace | `git diff --check` passed. |

Local results: `/tmp/planning-041-final-tests.xcresult` and `/tmp/planning-041-ios17-tests.xcresult`. No phone frame-rate improvement is claimed for this appearance update.

Physical-device checks remain: the familiar heading transition and circular control appearance, rapid tab-switch feel, Reduce Motion/Transparency, VoiceOver, and scrolling with the user's real task count. Timing and phone frame-rate claims from the prior performance notes are unchanged.
