# Planning 0.4 — Navigation and appearance

Release history for the 0.4 series, grouped by patch version. The latest documented patch is [0.4.2](#v0-4-2). Earlier sections describe behavior and validation at that release; later patches supersede those details.

## Versions

- [0.4.0 — Floating navigation and appearance](#v0-4-0)
- [0.4.1 — Heading and navigation polish](#v0-4-1)
- [0.4.2 — Consistent headers and soft scroll edges](#v0-4-2)

<a id="v0-4-0"></a>

## 0.4.0 — Floating navigation and appearance

Milestone selected November 11, 2026. In development; this does not declare the full planning foundation production-ready.

<a id="v0-4-0-scope-and-decisions"></a>

### Scope and decisions

Preserve the existing dark visual style and rounded task rows while adding a four-destination floating bottom bar. Active retains grouped tasks; Completed becomes its own screen. Archived is a placeholder. Settings implements System, Light, and Dark appearance; Dark remains the initial default. The choice persists through UserDefaults and applies at the app root.

Actual downward content movement of 36 points collapses the bar into a 60-point circle at the bottom left. It stays collapsed until tapped. Expansion establishes a fresh scroll baseline. Tab changes expand navigation and reset list position. The bar overlays the task list, keeping the viewport unchanged during collapse. End padding makes the last row reachable above the bar. Short lists, top/bottom rubber-banding, and reordering should not collapse navigation.

The existing row tap, stationary long press, swipe-delete, and drag/reorder gestures remain in place at the user's request. The existing immediate active-row drag can compete with list scrolling; use the list margin to scroll Active. Completed rows use normal tap and long-press gestures so they can scroll without entering reorder. A separate UX iteration will revisit gesture arbitration. Cross-group movement from the proposed 0.3.0 plan remains deferred. There is no change to task/group meaning, local persistence format, reminders, or backend contracts.

The shared **PlanningApp Demo** scheme loads a bundled JSON fixture in Debug via `-sample-data`. Its 24 active and 24 completed tasks use memory-only storage with no notification service. Demo edits reset on relaunch and do not modify saved tasks or real reminders. The normal scheme uses existing local data. Appearance preferences are shared between both schemes.

<a id="v0-4-0-acceptance-scenarios"></a>

### Acceptance scenarios

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

<a id="v0-4-0-implementation-and-compatibility"></a>

### Implementation and compatibility

The shell owns selection and a small deterministic collapse model. TaskStore remains the observable source of tasks and groups. Scroll reporting uses native geometry on iOS 18+ and preferences on iOS 17. The bar uses system Liquid Glass on iOS 26+ and material on earlier versions. This requires Xcode 26 to build while retaining iOS 17 support. No external packages or services are introduced.

<a id="v0-4-0-validation-evidence"></a>

### Validation evidence

Validated with Xcode 26.6 against the 0.4.0 implementation based on `209739a`. Automated tests were written before implementation; the initial run failed because the sample JSON resource had not yet been implemented.

| Environment | Result |
| --- | --- |
| iPhone 17 Pro, iOS 26.5 Simulator | 19 tests passed; 0 failures. |
| iPhone 15 Pro, iOS 17.2 Simulator | 19 tests passed; 0 failures, including preference-based scroll reporting and material navigation. |
| Source whitespace validation | `git diff --check` passed. |

The 19 tests comprise 15 unit tests and 4 UI tests. UI coverage includes all destinations, leading-circle collapse and expansion on both lists, completion/reopening, appearance selection and persistence, details, and new-task presentation. Results are available locally in `/tmp/planning-navigation-tests.xcresult` and `/tmp/planning-ios17-tests.xcresult`. Screenshot export and a separate Release build were declined, so visual inspection and Release validation remain pending. Local user testing follows the commit and push.

Remaining release checks: physical-device animation and drag feel; VoiceOver focus and discoverability; accessibility text sizes; Reduce Motion/Transparency; real notification delivery; upgrade with existing saved tasks; storage load/save failures. Existing silent data-loading/saving failure behavior is deferred and remains a foundation-readiness concern. This milestone does not certify the full lifecycle or accessibility coverage.

<a id="v0-4-0-navigation-ux-follow-up"></a>

### Navigation UX follow-up

The bar now lives under a stable shell rather than the conditional screen hierarchy. Its persistent, noninteractive selection highlight animates between all four tabs, including nonadjacent destinations; screen content crossfades with an explicit identity. Reduce Motion uses a short content fade and disables the moving highlight. The plus button shares the large Active heading's baseline with a minimum 44-point target. Existing task gestures remain unchanged.

Acceptance: switch Active → Settings → Active → Archived → Completed and back; the highlight travels continuously, the correct screen fades in, and the plus appears beside Active. Automated checks verify selection/header consistency and plus alignment; perceived animation smoothness remains a physical-device check.

The UX follow-up also makes the task viewport extend behind navigation and reduces heading padding. Completed rows no longer install an unused reorder recognizer; full-row scrolling can collapse navigation in Completed. The collapse UI test now scrolls directly over completed rows. The active-task drag behavior is preserved.

Regression testing caught oversized accessibility/hit bounds from a matched-geometry background after switching through Settings. A single decorative capsule now moves behind stable tab buttons; it does not participate in hit testing or accessibility.

UX validation: the iOS 17.2 full 20-test run passed completed-row scrolling/collapse, task completion, details, and 15 unit tests, while exposing two navigation regressions. After replacing the matched background, both failing navigation tests passed on iOS 17.2 (`/tmp/planning-ux-regression-tests.xcresult`). The earlier shell/header changes also passed the 20-test run on iOS 26.5 before the viewport change. Physical-device animation and rapid-tap feel remain to be tested.

<a id="v0-4-0-separate-optimization-follow-up"></a>

### Separate optimization follow-up

The scroll controller now publishes only visible collapse changes. Drag-frame measurements are kept outside observable UI state, Completed omits those measurements, task-array animation comparison moves to the stack, and grouping uses a single pass. See [performance evidence and phone comparison steps](PERFORMANCE.md). This preserves the UX commit as a separate comparison point and does not claim measured phone frame-rate improvements.

Optimization validation: 23 tests passed on iOS 26.5 and 24 on iOS 17.2, including the added real drag/reorder scenario. The Release build for the iPhone device SDK passed with signing disabled. The synthetic grouping benchmark fell from 0.525 seconds to 0.007 seconds for five reads; see the performance notes for configuration and limits. Physical-device smoothness remains to be assessed locally.

<a id="v0-4-1"></a>

## 0.4.1 — Heading and navigation polish

November 11, 2026. Appearance, animation, and scroll-observation fixes following the 0.4.0 UX/performance commits. Existing task gestures, one-pass grouping, measurement caching, distinct state publication, data format, reminders, and appearance preferences are retained.

<a id="v0-4-1-behavior"></a>

### Behavior

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

<a id="v0-4-1-acceptance-and-validation"></a>

### Acceptance and validation

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

<a id="v0-4-2"></a>

## 0.4.2 — Consistent headers and soft scroll edges

November 11, 2026. Visual polish following 0.4.1. The chosen behavior remains the same large-to-compact scroll transition on every tab, rather than always-compact headings.

<a id="v0-4-2-changes"></a>

### Changes

Page scroll indicators are hidden through SwiftUI's scoped scroll-indicator environment, removing the visible scrollbar/gutter. Content padding, scrolling gestures, and scrollable range are retained.

All four tabs use the same header font, centering, height rules, transition, and scroll state. Active's circular add control overlays the trailing edge instead of affecting title layout. Archived now uses the existing scroll observer as well, with a placeholder sized to fit the viewport and bottom navigation clearance. A page that fits without scrolling retains its large heading and expanded navigation; content that overflows follows the same transition as Active and Completed.

A 24-point material-and-color fade sits just below the compact header, softening text and rows as they pass underneath. The strip is shared by every page, sits above content, and neither reserves additional layout space nor intercepts touches. Reduce Transparency uses the color fade without the material blur. Reduce Motion retains the existing short transition.

The effect is limited to the shallow header edge. No whole-page blur, snapshots, timers, or per-pixel view-state publication is introduced. The grouping algorithm, drag-frame cache, scroll-controller publication rules, data formats, reminders, task gestures, appearance choices, and stable bottom-bar positioning are unchanged.

<a id="v0-4-2-acceptance-and-verification"></a>

### Acceptance and verification

- Active and Completed transition to identically styled compact titles while scrolling, and return to large headings near the top.
- Settings uses the same compact title and soft edge when its content overflows; Archived has the same scroll path when needed.
- The circular add control remains aligned and opens the task editor.
- Visible page scroll indicators are absent during and after scrolling.
- Text crossing the compact header boundary fades/softens without a hard cutoff or a new blank gutter.
- Tab changes retain fixed floating-bar bounds, and task interactions remain functional.

Automated checks retain the existing navigation, heading, Settings/Archived scroll behavior, task, appearance, and performance coverage, with added centered-title assertions and screenshots for the compact Active, Completed, and Settings headers. Visual QA covers the soft edge and indicator visibility. Validation results:

| Check | Result |
| --- | --- |
| iPhone 17 Pro, iOS 26.5 Simulator | Full suite: 27 tests passed (20 unit, seven UI). |
| iPhone 15 Pro, iOS 17.2 Simulator | Three focused UI checks passed, including explicit dark appearance, Settings/Archived behavior, and fixed navigation bounds. |
| Release build, iPhone device SDK | Passed with signing disabled. |
| Built metadata | Version 0.4.2, build 3. |
| Visual QA | Inspected compact Active, Completed, and Settings edges; light iOS 26.5 and dark iOS 17.2 screenshots show the fade and hidden indicators. Settings screenshots use the largest accessibility text size. |
| Whitespace | `git diff --check` passed. |

Local result bundles: `/tmp/planning-042-tests.xcresult` and `/tmp/planning-042-ios17-tests.xcresult`. The iOS 17 task-scroll check explicitly selects Dark before scrolling. Device animation feel and Reduce Transparency/VoiceOver remain local release checks; this polish update makes no new device frame-rate claims.
