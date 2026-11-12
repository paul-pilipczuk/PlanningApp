# Planning 0.4.2 — Consistent headers and soft scroll edges

November 11, 2026. Visual polish following 0.4.1. The chosen behavior remains the same large-to-compact scroll transition on every tab, rather than always-compact headings.

## Changes

Page scroll indicators are hidden through SwiftUI's scoped scroll-indicator environment, removing the visible scrollbar/gutter. Content padding, scrolling gestures, and scrollable range are retained.

All four tabs use the same header font, centering, height rules, transition, and scroll state. Active's circular add control overlays the trailing edge instead of affecting title layout. Archived now uses the existing scroll observer as well, with a placeholder sized to fit the viewport and bottom navigation clearance. A page that fits without scrolling retains its large heading and expanded navigation; content that overflows follows the same transition as Active and Completed.

A 24-point material-and-color fade sits just below the compact header, softening text and rows as they pass underneath. The strip is shared by every page, sits above content, and neither reserves additional layout space nor intercepts touches. Reduce Transparency uses the color fade without the material blur. Reduce Motion retains the existing short transition.

The effect is limited to the shallow header edge. No whole-page blur, snapshots, timers, or per-pixel view-state publication is introduced. The grouping algorithm, drag-frame cache, scroll-controller publication rules, data formats, reminders, task gestures, appearance choices, and stable bottom-bar positioning are unchanged.

## Acceptance and verification

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
