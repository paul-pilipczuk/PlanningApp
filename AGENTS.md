# Planning development

Read README.md and docs/UX_CONVENTIONS.md for product behavior. Follow the existing SwiftUI style and iOS 17 deployment baseline.

## Performance is a product requirement

Keep Planning lightweight and responsive as features and saved data grow, including on older supported iPhones. Consult docs/PERFORMANCE.md before changing task rendering, scroll/drag state, persistence, or visual effects.

- Avoid repeated filtering, sorting, allocations, full-array comparisons, and disk work in view bodies or per-frame gesture/scroll callbacks.
- Publish only meaningful visible state changes. Keep lazy rendering and stable task identities.
- Bound derived caches to current data, invalidate them on every relevant mutation, and release expendable caches under memory pressure.
- Preserve atomic saves, failure rollback, data migration, and reminder correctness while optimizing.
- Measure the relevant path before/after with the same fixture/configuration. Separate cold and repeated-read behavior; do not equate simulator timings with phone FPS or battery improvements.
- Test on a smaller supported layout and document physical-device checks with Low Power Mode both off and on. Do not assume Low Power Mode explains lag without evidence.

Use focused commits within a release branch. For the authorized release workflow, branch from freshly pulled main, review the full diff and behavioral regressions, then squash-merge the versioned PR and delete its source branch. Honor any owner request to test locally before pushing.

Keep unrelated local Xcode user-state changes out of release commits.
