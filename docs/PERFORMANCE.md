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

<a id="v0-6-progress"></a>

## 0.6.0 optional progress

Progress preserves lazy rendering and adds cached stable partitions within each task group. Progress rows and section headers share one identity domain so a task can move between labels without destroying its active drag gesture. Group/label candidates, marker lookups, and marker positions are bounded to current data and discarded with the presentation caches. A section drop compares its destination and marker directly rather than comparing the full task array during drag updates. Configuration saves and final order saves retain the atomic snapshot contract.

The fixed 10,000-task Release fixture and the original two benchmark methods are unchanged. An isolated checkout of `34b6db2` supplied the prior build; both versions used the same iPhone 17 Pro/iOS 26.5 destination, Xcode 26.6, sequential execution, and `ENABLE_TESTABILITY=YES`. Two added methods apply the same workload with progress enabled and alternating assignments across the two labels. Each result averages five iterations.

| Store collection work | Prior build | Progress off | Progress on |
| --- | --- | --- | --- |
| 50 warmed collection/count reads | 0.000268 s | 0.000276 s | 0.000288 s |
| Five fresh stores with complete collection reads | 0.127950 s | 0.129039 s | 0.161980 s |

The enabled feature has extra cold work for label partitions and stable presentation rows. Its final two cases also read the global row projection; the original default-off methods retain their baseline workload. Default-off cold collection work was about 1% higher in this comparison; the warm difference was about 0.008 milliseconds for the entire 50-read loop. Reading the additional global row projection with progress off took 0.134965 seconds for five fresh stores, compared with 0.129039 seconds for the original collection-only workload. These are store measurements, not row-layout, frame-rate, or energy results. Early runs under different simulator load varied more, so the original isolated checkout was rerun under the current conditions; those earlier bundles are retained rather than treated as an optimization result.

Progress adds a task reference field and retained current-data projections, so it does not claim a memory reduction. XCTest memory metrics are recorded in the bundles; different case order and allocator reuse prevent attributing process peak differences solely to caches. Purge/freshness tests establish that cached label lookups, positions, sections, and candidates rebuild correctly without publishing or altering saved data.

Evidence: `/tmp/planning-progress-baseline-controlled.xcresult` and `/tmp/planning-progress-complete-unit.xcresult`. Earlier measurements: `/tmp/planning-060-progress-baseline.xcresult`, `/tmp/planning-060-progress-measured.xcresult`, and `/tmp/planning-progress-final-release-unit.xcresult`. Repeat the physical-phone comparison with progress off/on, the same task data, and Low Power Mode off/on before drawing conclusions about interaction smoothness.


The later cross-task-group extension uses one global row identity domain. It removes the intermediate per-group row arrays and derives global rows from the current progress partitions. Group/progress assignment is deferred until release; hovering only changes the pending destination/preview, and an unchanged destination does not rescan empty groups. Same-label reorder still previews live. The final enabled benchmarks also read the global row cache; an added disabled-mode cold-presentation case measures that new projection separately from the unchanged original collection baseline. Their evidence is recorded in the final 0.6 release validation.
