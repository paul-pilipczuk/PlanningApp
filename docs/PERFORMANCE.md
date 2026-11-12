# Performance follow-up

This change follows the navigation UX commit `94b9869` and stays separate so phone behavior can be compared. It targets redundant work found in source inspection. It does not attribute the reported phone lag to a particular cause or claim a measured improvement in device frame rate or battery life.

## Changes

- `FloatingNavigationController` keeps scroll history private and publishes only when collapsed state changes. Pixel-by-pixel offsets no longer invalidate the root screen and navigation bar.
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
