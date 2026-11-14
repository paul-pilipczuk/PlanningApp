# Planning 0.5.5 — Lightweight task updates

November 13, 2026 · Version 0.5.5, build 9

Planning avoids rebuilding filtered, sorted, and grouped task collections during repeated view updates. Derived collections are lazy, bounded to current data, invalidated after mutations, and discarded on memory warnings. Dragging queries the active task’s group rather than filtering the entire store for every movement. Task animation checks use a revision token rather than full-array equality.

Appearance, task gestures, data schema, atomic saving, failure recovery, reminders, Archive/Completed Copy flows, and system accessibility settings retain their current behavior. No new runtime packages, timers, or services are introduced. Cold collection work and synchronous persistence remain; this patch targets redundant repeated work.

Lightweight, responsive operation is now an explicit standing requirement in README, AGENTS.md, [performance guidance](PERFORMANCE.md), and [interface conventions](UX_CONVENTIONS.md), including older supported iPhones and recorded Low Power Mode comparisons.

## Measurement and validation

The same Release simulator benchmark with 10,000 tasks measured 50 warmed collection reads at 1.271 seconds before and about 0.27 milliseconds after optimization. Five cold stores/read passes stayed near 0.13 seconds. Peak physical footprints were similar in these runs; caching has a bounded memory cost and an explicit purge path. See [the measurement protocol and limitations](PERFORMANCE.md#beforeafter-measurement).

All 39 unit tests and the full 18-test UI suite passed on iOS 26.5. All 39 unit tests also passed on iOS 17.2, together with six focused narrow iPhone SE UI checks for drag/reorder, scroll collapse/expansion, Completed Copy, copy cancellation/scroll retention, short-list menus/deletion, and archive/restore. The final Release device-SDK build passed with signing disabled.

Evidence: `/tmp/planning-055-unit.xcresult`, `/tmp/planning-055-ui.xcresult`, `/tmp/planning-055-ios17-unit.xcresult`, `/tmp/planning-055-ios17-ui.xcresult`, and `/tmp/planning-055-release-final.log`, plus the before/after benchmark bundles linked above.

Code review checked every mutation/reload/rollback invalidation path, raw group membership, archive ordering, cache bounds and purge, publication behavior, animation revision, and unchanged persistence/reminder semantics. A review correction avoids retaining arbitrary empty group queries. Warm-cache regressions verify current data after lifecycle changes, group reload, rollback, and purge. Physical-device SwiftUI/Time Profiler traces, frame pacing, energy use, and Low Power Mode behavior still require the phone comparison; simulator SE checks validate layout/compatibility, not that phone’s CPU speed.

## Device comparison

1. Use identical saved plans, phone model, iOS, appearance, thermal conditions, and Release configuration for 0.5.4 and 0.5.5. The Debug-only Demo fixture is not loaded in Release.
2. Compare tab changes, scrolling every page, dragging within a group, opening/editing details, completing/reopening, archive/restore, and Copy/cancellation.
3. Repeat with Low Power Mode off and on, recording the condition. Keep accessibility accommodations enabled when checking their performance.
4. Profile with the SwiftUI and Time Profiler instruments if a hitch remains, and record the action, data size, and trace. Verify save/relaunch and failure behavior alongside smoothness.
