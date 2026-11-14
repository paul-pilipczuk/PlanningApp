# Planning 0.5.1 — Simple actions

November 13, 2026 · Version 0.5.1, build 5

Task actions use short verbs without trailing punctuation: Restore, Archive, Remove, and Delete. The same wording appears in archived details, archive menus, completed removal choices, editors, and delete confirmations. Restore still returns a task to Completed. Delete still requires a native confirmation that names the task and explains irreversible removal.

Given an archived task, opening its actions or details shows short complete words. Cancelling deletion retains the task. Confirming deletion removes only that task. Archiving and restoration retain their existing behavior.

The new [interface conventions](UX_CONVENTIONS.md) make concise action labels and avoiding split words repository rules while retaining Dynamic Type and 44-point targets. Test narrow phones and larger text sizes locally.

Validation: three targeted UI regressions passed on iOS 26.5 (archive/restore, Completed delete cancel/confirm, and Archived delete cancel/confirm); Release device-SDK build passed with code signing disabled. Evidence: `/tmp/planning-051-ui-clean.xcresult` and `/tmp/planning-051-release.log`. The first reused simulator failed test-runner preflight with SpringBoard Busy before executing tests; the clean simulator run passed.
