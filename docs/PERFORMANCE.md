# Performance and lightweight design

## Standing requirement

Planning must remain lightweight and responsive as features and task data grow, including on older supported iPhones. Evaluate CPU work, allocations, memory residency, and interaction latency as part of feature design and code review. Preserve the current visual style and accessibility accommodations while reducing redundant work.

Keep per-frame scroll/gesture callbacks small, render lazily, avoid repeating collection transformations in view bodies, and publish only meaningful state changes. Derived caches must remain bounded to current data, invalidate correctly, and be expendable under memory pressure. Correct saving, migration, reminder cancellation, and recovery from failures remain requirements during performance work.

Use repeatable before/after measurements with the same fixture, build configuration, simulator/phone, and action. Separate cold work from repeated reads; record CPU/memory tradeoffs. Use the physical-device workflow below for actual SwiftUI updates and hitches. Simulator layout checks on an iPhone SE do not emulate that phone’s processor speed, and synthetic benchmarks do not establish frame rate or battery life.

Low Power Mode is a comparison condition, not an established cause of reported lag. Record it alongside phone model, OS, thermal state, dataset, and Release build. Check both on and off when assessing interactions on device.

## 0.5.5 task presentation work

The store now lazily retains the current active/completed/archived projections, grouped sections, group names, and groups used by dragging. A task replacement invalidates every task-derived projection; group changes invalidate section/name projections. Failed saves retain the current data, and rollback/reload replace the projections with the restored state. Empty arbitrary group queries are not retained, bounding group cache keys to current active data. A memory warning discards the projections without publishing state, changing task identity, or writing data.

Drag handling captures the task’s group when the drag begins and queries only that group while moving. Candidate order still refreshes after each reorder; raw group membership, thresholds, frame measurements, haptics, and save-on-release behavior stay intact. The list compares a small task-revision token for implicit animation instead of comparing the full task array on each view update.

### Before/after measurement

Both runs used Xcode 26.6 (17F113), Release with `ENABLE_TESTABILITY=YES`, the same iPhone 17 Pro / iOS 26.5 simulator destination and Apple Silicon host, sequential execution, and the identical benchmark code from `f8a4add`. The fixed-shape fixture has 10,000 tasks across 100 named groups and General: 6,000 active, 2,000 completed, 2,000 archived, with fixed archive dates including ties. Fixture creation occurs outside the timed interval. Each result averages five XCTest metric iterations.

| Timed work | Before | After |
| --- | --- | --- |
| 50 reads of all task collections and grouped counts, after one warm-up read | 1.271 s | 0.000266 s (0.27 ms) |
| Five fresh in-memory stores, one complete collection read per store | 0.130 s | 0.128 s |

The repeated-read result isolates removed collection work. Cold work is effectively unchanged within these runs’ variation. These are not frame-rate or battery measurements. First reads still perform filtering/grouping/sorting, and local JSON persistence retains its synchronous atomic-save contract. Physical-device profiling must establish any remaining hitch source before redesigning those paths.

XCTest peak physical footprint was roughly 39 MB for the cold case and 27 MB for the warm case in both runs; the small differences are not evidence of a memory improvement or a leak test. Cached value arrays consume memory while retained. Their contents are bounded to the current dataset, created only when requested, invalidated on relevant mutations, and discarded under memory pressure.

Evidence: `/tmp/planning-055-baseline.xcresult` and `/tmp/planning-055-optimized.xcresult`; logs use the same names with `.log`. Reproduce with the two `SampleTaskDataTests` methods `testRepeatedTaskCollectionReadsPerformance` and `testColdTaskCollectionsPerformance` under Release, code signing disabled, and `ENABLE_TESTABILITY=YES`. No stored absolute timing gate is imposed; compare equivalent runs and retain correctness regressions alongside timing evidence.

## Historical 0.4.0 follow-up

This change follows the navigation UX commit `94b9869` and stays separate so phone behavior can be compared. It targets redundant work found in source inspection. It does not attribute the reported phone lag to a particular cause or claim a measured improvement in device frame rate or battery life.

## Changes

- `FloatingNavigationController` keeps scroll history private and publishes only when collapsed state changes (and, in 0.4.1, when the heading crosses a compact/expanded threshold). Pixel-by-pixel offsets no longer invalidate the root screen and navigation bar.
- Active-row geometry goes into a reference cache used by drag handling, rather than observable view state. Completed rows do not install drag-frame measurement readers.
- Task-array animation comparison occurs once at the lazy stack, instead of once per row.
- Active tasks are partitioned into groups in one pass, preserving group order, task order, General, and empty-group behavior. Drag lookup also avoids building unnecessary intermediate active-task arrays.

The app keeps its current appearance, task gestures, iOS 17 support, persistence format, and save semantics. No packages, timers, background services, or permanent task caches are added. File loading/saving still occurs synchronously; if phone profiling identifies that as a hitch source, moving it off the main actor needs a separate design for ordered writes, failure handling, and lifecycle durability.

This follows Apple's guidance to [reduce unnecessary SwiftUI updates and geometry dependencies](https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance). Actual frame-time investigation should use the [SwiftUI Instruments workflow](https://developer.apple.com/videos/play/wwdc2025/306/).

## Repeatable checks

The update-publication test first failed with unconditional publishing, then passed after publication was restricted to visible state changes. It feeds 1,001 increasing offsets and observes only the initial expanded state and one collapse notification; expansion and tab resets also require fresh movement and do not emit duplicate states.

The grouping benchmark constructs 10,000 tasks across 100 named groups, including completed tasks and General, outside the timed interval. Each measurement reads and counts the grouped list five times; XCTest records ten measurements. Both runs use Xcode 26.6, Debug configuration, an iPhone 17 Pro / iOS 26.5 simulator, and sequential testing.

| Implementation | Mean time for five grouped-list reads |
| --- | --- |
| Before single-pass grouping | 0.525 seconds |
| After single-pass grouping | 0.007 seconds |

These are synthetic simulator results for grouping only, with no stored XCTest baseline or absolute timing gate. They are not an end-to-end animation benchmark. Tests also verify task/group ordering through reordering, completion, and reopening.

## Phone comparison

1. Use the same iPhone, data, appearance, and thermal conditions for each build.
2. Test the UX commit `94b9869`, then the separate optimization commit. Compare scrolling through Completed, scrolling the Active margin, dragging active tasks, switching adjacent and nonadjacent tabs, opening details, and completing/reopening tasks.
3. Test once with Low Power Mode off and once with it on, recording the setting instead of assuming it explains a difference.
4. Use Product → Profile with the PlanningApp scheme for a Release build and inspect SwiftUI updates, Time Profiler, and animation hitches. The demo scheme's sample-data launch argument is Debug-only; Release uses saved local plans.
5. Record phone model, iOS version, build configuration, data size, Low Power Mode, and the action that hitches. Check that the last task can scroll above navigation and that Completed collapses while swiping over rows.

The unit/UI suite and a device-SDK Release build are checked for this change; physical-device frame time, VoiceOver, and gesture feel still require local validation.

## Validation record

The 23-test suite (18 unit tests and five UI tests) passed on iPhone 17 Pro / iOS 26.5. The optimized app also built successfully in Release for the iPhone device SDK with signing disabled. The final iPhone 15 Pro / iOS 17.2 run passed all 24 tests (18 unit tests and six UI tests), including an additional drag/reorder regression verifying that geometry caching preserves the current interaction. Result bundles are local under `/tmp/planning-optimized-tests.xcresult` and `/tmp/planning-optimized-ios17-tests.xcresult`.
