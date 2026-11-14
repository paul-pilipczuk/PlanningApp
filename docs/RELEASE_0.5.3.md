# Planning 0.5.3 — Condensed Settings

November 13, 2026 · Version 0.5.3, build 7

Settings uses sentence-case section headings, consistent card spacing, and the same 16-point page margins as task lists. Detached explanatory summaries are removed. About keeps a concise storage/retention note inside its card and combines version/build into one row. The Notifications section has a short Settings action with a full accessibility label. Label/value rows switch to a vertical layout when there is insufficient room to keep their words intact.

System appearance remains an option, and iPhone accessibility settings still apply automatically. VoiceOver hints retain useful guidance about the navigation/haptic controls and notification permission. Preferences, permission refresh on return, notification opt-in, and task reminders retain their existing behavior.

Given Settings in either appearance or larger text, controls remain legible and reachable without uppercase headers or detached paragraphs. Changing navigation/haptics and relaunching retains both independent choices. Changing appearance still applies throughout the app. Overflow scrolling still compacts the heading and collapses navigation when permitted.

Initial validation passed three focused iOS 26.5 UI checks (appearance/relaunch, independent navigation/haptic persistence, and large-text overflow scrolling) and the Release device-SDK build. Visual review caught a pre-existing horizontal label/value issue that split “Permission” at the largest text size; this candidate adds an adaptive stacked layout and a readability regression test. After the fix, the largest-text readability test and the independent navigation/haptic persistence regression both passed on iOS 26.5; the final Release build also passed. The corrected largest-text screenshot was inspected and keeps Permission and its value intact. Local evidence: `/tmp/planning-053-ui.xcresult`, `/tmp/planning-053-a11y.xcresult`, and `/tmp/planning-053-release-final.log`.

The owner tested the local 0.5.3 build and approved it on November 13 before the branch was pushed. 0.5.4 follows this release. Physical VoiceOver and hardware haptics remain device checks.

Code review checked both layout commits for preference binding/key changes, permission prompting, notification refresh on return, Dynamic Type, semantic colors, and hit targets. The settings behavior remains intact; the visual review finding above is fixed before local handoff.
