# Planning 0.4.0 — Floating navigation and appearance

Milestone selected November 11, 2026. In development; this does not declare the full planning foundation production-ready.

## Scope and decisions

Preserve the existing dark visual style and rounded task rows while adding a four-destination floating bottom bar. Active retains grouped tasks; Completed becomes its own screen. Archived is a placeholder. Settings implements System, Light, and Dark appearance; Dark remains the initial default. The choice persists through UserDefaults and applies at the app root.

Actual downward content movement of 36 points collapses the bar into a 60-point circle at the bottom left. It stays collapsed until tapped. Expansion establishes a fresh scroll baseline. Tab changes expand navigation and reset list position. The bar overlays the task list, keeping the viewport unchanged during collapse. End padding makes the last row reachable above the bar. Short lists, top/bottom rubber-banding, and reordering should not collapse navigation.

The existing row tap, stationary long press, swipe-delete, and drag/reorder gestures remain in place at the user's request. The existing immediate active-row drag can compete with list scrolling; use the list margin to scroll Active. Completed rows use normal tap and long-press gestures so they can scroll without entering reorder. A separate UX iteration will revisit gesture arbitration. Cross-group movement from the proposed 0.3.0 plan remains deferred. There is no change to task/group meaning, local persistence format, reminders, or backend contracts.

The shared **PlanningApp Demo** scheme loads a bundled JSON fixture in Debug via `-sample-data`. Its 24 active and 24 completed tasks use memory-only storage with no notification service. Demo edits reset on relaunch and do not modify saved tasks or real reminders. The normal scheme uses existing local data. Appearance preferences are shared between both schemes.

## Acceptance scenarios

| Given | When | Then |
| --- | --- | --- |
| The app launches | The root appears | Active is selected and all four destinations are available. |
| A scrollable task list | Content moves downward at least 36 points | The bar smoothly becomes a leading circle without shifting the list. |
| An expanded bar | The list jitters or rubber-bands at an edge | Navigation remains expanded. |
| A collapsed bar | The user scrolls upward | The bar remains collapsed. |
| A collapsed bar | Its circle is tapped | All four tabs return, with the current selection retained. |
| Expanded navigation | Another tab is selected | Its content appears at the top with navigation expanded. |
| An active task | The task is completed | It appears in Completed and keeps its group. |
| A completed task | It is marked active | It returns to its active group. |
| Any destination | Archived is selected | “Coming soon” is shown. |
| Settings | Light, Dark, or System is chosen | The app and sheets use that appearance, including after relaunch. |
| A demo session | Tasks are changed, then relaunched | The fixture reloads; saved task files remain unchanged. |
| VoiceOver is enabled | Lists scroll | Navigation remains expanded and tabs announce their selection. |
| Reduce Motion or Reduce Transparency is enabled | The bar changes state | Navigation uses a short transition or opaque surface respectively. |

## Implementation and compatibility

The shell owns selection and a small deterministic collapse model. TaskStore remains the observable source of tasks and groups. Scroll reporting uses native geometry on iOS 18+ and preferences on iOS 17. The bar uses system Liquid Glass on iOS 26+ and material on earlier versions. This requires Xcode 26 to build while retaining iOS 17 support. No external packages or services are introduced.

## Validation evidence

Validated with Xcode 26.6 against the 0.4.0 implementation based on `209739a`. Automated tests were written before implementation; the initial run failed because the sample JSON resource had not yet been implemented.

| Environment | Result |
| --- | --- |
| iPhone 17 Pro, iOS 26.5 Simulator | 19 tests passed; 0 failures. |
| iPhone 15 Pro, iOS 17.2 Simulator | 19 tests passed; 0 failures, including preference-based scroll reporting and material navigation. |
| Source whitespace validation | `git diff --check` passed. |

The 19 tests comprise 15 unit tests and 4 UI tests. UI coverage includes all destinations, leading-circle collapse and expansion on both lists, completion/reopening, appearance selection and persistence, details, and new-task presentation. Results are available locally in `/tmp/planning-navigation-tests.xcresult` and `/tmp/planning-ios17-tests.xcresult`. Screenshot export and a separate Release build were declined, so visual inspection and Release validation remain pending. Local user testing follows the commit and push.

Remaining release checks: physical-device animation and drag feel; VoiceOver focus and discoverability; accessibility text sizes; Reduce Motion/Transparency; real notification delivery; upgrade with existing saved tasks; storage load/save failures. Existing silent data-loading/saving failure behavior is deferred and remains a foundation-readiness concern. This milestone does not certify the full lifecycle or accessibility coverage.

## Navigation UX follow-up

The bar now lives under a stable shell rather than the conditional screen hierarchy. Its persistent, noninteractive selection highlight animates between all four tabs, including nonadjacent destinations; screen content crossfades with an explicit identity. Reduce Motion uses a short content fade and disables the moving highlight. The plus button shares the large Active heading's baseline with a minimum 44-point target. Existing task gestures remain unchanged.

Acceptance: switch Active → Settings → Active → Archived → Completed and back; the highlight travels continuously, the correct screen fades in, and the plus appears beside Active. Automated checks verify selection/header consistency and plus alignment; perceived animation smoothness remains a physical-device check.

The UX follow-up also makes the task viewport extend behind navigation and reduces heading padding. Completed rows no longer install an unused reorder recognizer; full-row scrolling can collapse navigation in Completed. The collapse UI test now scrolls directly over completed rows. The active-task drag behavior is preserved.

Regression testing caught oversized accessibility/hit bounds from a matched-geometry background after switching through Settings. A single decorative capsule now moves behind stable tab buttons; it does not participate in hit testing or accessibility.

UX validation: the iOS 17.2 full 20-test run passed completed-row scrolling/collapse, task completion, details, and 15 unit tests, while exposing two navigation regressions. After replacing the matched background, both failing navigation tests passed on iOS 17.2 (`/tmp/planning-ux-regression-tests.xcresult`). The earlier shell/header changes also passed the 20-test run on iOS 26.5 before the viewport change. Physical-device animation and rapid-tap feel remain to be tested.
