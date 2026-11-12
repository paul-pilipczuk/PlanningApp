# Planning

A small, fully offline planning app for iPhone, built in SwiftUI.

Planning is a learning project with a practical goal: create a calm, low-friction task experience that works well for people with different levels of technical confidence and different ways of interacting with their phone. It favors obvious actions, familiar system controls, readable dark-mode presentation, and device-local privacy over feature density.

## Product principles

- **Make the next action obvious.** Empty space adds a plan, a task tap completes it, a long press opens its details, and the trailing cog provides a direct details route.
- **Keep the interface small.** The main screen focuses on the user’s current plans rather than menus, accounts, or configuration.
- **Use familiar iOS patterns.** Sheets, buttons, menus, date pickers, and system icons make the experience easier to learn.
- **Respect attention.** Reminders are opt-in, local to the device, and can repeat only until the task is finished.
- **Respect privacy.** There is no account, network connection, analytics service, cloud sync, or remote notification server.
- **Build accessibly by default.** The app uses SwiftUI system controls, clear action labels for assistive technologies, large row-level actions, and system text styles that respond to the user’s preferred text size.

This does not claim to solve every accessibility need. It is a foundation intended to be tested with real people and improved iteratively.

## Current experience

| Action | Result |
| --- | --- |
| Tap unused space in the plan list | Opens the new-task sheet |
| Enter a task title, optional group and description, then tap **Add** | Saves a task on the device |
| Tap a task | Marks it complete or incomplete |
| Long-press a task, or tap its cog | Opens task details, including description, group, and reminders |
| Swipe left on an active task | Replaces its cog with a Delete button |
| Press and hold a task | Lifts it above the list while nearby tasks preview their new positions |
| Enable notifications | Chooses daily or weekly timing, a time of day, and whether to repeat until completion |

The floating bottom bar has four destinations: **Active**, **Completed**, **Archived**, and **Settings**. Active shows grouped unfinished plans; Completed shows finished plans with a checkmark, strikethrough text, and reduced emphasis. Archived is a “Coming soon” placeholder.

Scrolling down through Active, Completed, or Settings collapses the bar into a circle at the bottom left. Tap that circle to expand navigation. It stays collapsed when scrolling back up; selecting another tab expands it and starts that list at the top. The bar overlays the list without changing its viewport; end padding lets the last task scroll above it. The bar stays anchored while switching tabs, and the selection highlight slides between destinations.

Large page headings transition to compact titles after scrolling and return to their large size near the top. The circular Add task button stays aligned with Active in both sizes.

Collapse requires actual scrollable content. A short Completed list or Settings page can fit entirely on screen and keep the bar expanded. Archived is a static placeholder and does not collapse navigation. The Demo scheme includes enough completed tasks to exercise scrolling.

Settings offers **System**, **Light**, and **Dark** appearance. Dark is the initial default; your choice applies to sheets and navigation and survives relaunch. The app retains its rounded task rows and familiar system controls in both appearances.

The existing active-task drag interaction is preserved for a separate UX iteration. A vertical drag beginning on an active task can reorder it; scrolling in the list margin moves that list. Completed rows scroll normally. Reordering does not collapse navigation.

Completing a task moves it to Completed; marking it active returns it to its group. Completing a task cancels its pending reminder. Marking it incomplete schedules the reminder again if it remains enabled.

## Privacy and reminders

All task data is stored locally as JSON in the app’s Application Support directory. The app does not send task content off the phone.

Reminders use `UNUserNotificationCenter`, Apple’s local-notification API. When notifications are enabled for a task, iOS asks for permission. A daily reminder repeats each day at the selected time; a weekly reminder repeats on the chosen weekday and time. If **Repeat until done** is turned off, only the next matching notification is scheduled.

Because notifications are local, test them on a physical iPhone as well as the Simulator. Delivery timing and notification permission are ultimately controlled by iOS.

## Requirements

- macOS with Xcode 26 or later (for the guarded Liquid Glass implementation)
- iOS 17 or later
- An Apple Account in Xcode to run on a personal device

No third-party packages or backend services are required.

## Run locally

1. Open `PlanningApp.xcodeproj` in Xcode.
2. Select the **PlanningApp** scheme.
3. Choose an iPhone Simulator or a connected iPhone.
4. Click **Run** (▶).

For a physical iPhone, open the target’s **Signing & Capabilities** tab, select your Team, and keep **Automatically manage signing** enabled. If iOS prompts you, trust the Mac and enable Developer Mode under **Settings → Privacy & Security → Developer Mode**.

## Project structure

```text
PlanningApp/
├── Models/
│   ├── AppAppearance.swift            # System, Light, and Dark preferences
│   ├── FloatingNavigationState.swift  # Tabs and scroll-collapse rules
│   └── TaskItem.swift                 # Task, group, and reminder data
├── Services/
│   ├── NotificationManager.swift      # Local notification scheduling
│   ├── SampleTaskData.swift           # Bundled demonstration data
│   └── TaskStore.swift                # On-device JSON persistence
├── Views/
│   ├── AddTaskView.swift              # Unified create/details editor
│   ├── PlanningRootView.swift         # Four-tab app shell
│   ├── FloatingNavigationBar.swift    # Expanding floating navigation
│   ├── AppSettingsView.swift          # Appearance preferences
│   ├── TaskScrollObserver.swift       # iOS 17+ scroll reporting
│   └── TaskListView.swift             # Active and completed lists
├── Resources/
│   └── SampleTasks.json               # 24 active + 24 completed samples
└── PlanningApp.swift                   # App entry point
```

### Try the sample tasks

Select the shared **PlanningApp Demo** scheme in Xcode and Run. It uses `-sample-data` in Debug to load 24 active and 24 completed tasks across named groups and General. You can edit, complete, delete, and reorder them freely. Demo task changes are memory-only and reset on relaunch; saved task files and real reminders are untouched. Select **PlanningApp** to return to your saved plans. Appearance is a persistent app preference in either scheme.

### Run automated checks

Both shared schemes include unit and UI test targets. Run Product → Test in Xcode, or:

```bash
xcodebuild test -project PlanningApp.xcodeproj -scheme PlanningApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Use a simulator name installed on your Mac. [The 0.4.1 fix notes](docs/RELEASE_0.4.1.md) record scope, scenarios, and validation limitations.

See [performance notes and the phone comparison steps](docs/PERFORMANCE.md) for the separate optimization follow-up.

Additional project documents:

- `TESTINGMETHODOLOGY.md` defines the tests-first, TDD, BDD, and release-validation approach.
- `InternalDocs/IMPLEMENTATION_PLAN.md` explains the original intentionally lean scope.
- `InternalDocs/SWIFT_CONCEPTS.md` links key SwiftUI concepts to concrete files and lines of code.
- `InternalDocs/` is local-only working documentation and is intentionally excluded from Git.

## Architecture

The app deliberately keeps its architecture simple:

- `TaskItem` and `ReminderSettings` are small `Codable` value types.
- `TaskStore` is the single observable source of task state. It loads data when the app starts and saves after each user change.
- SwiftUI views receive the store through `@EnvironmentObject` and keep sheet presentation state locally with `@State`.
- `NotificationManager` owns notification permission, scheduling, and cancellation, keeping platform APIs out of the views.

The app defaults to dark appearance and stores the selected `AppAppearance` in `@AppStorage`; the root applies `preferredColorScheme` across the app. It is intentionally a focused iPhone experience rather than a broad, multi-platform product.

## UX and accessibility checklist

The current implementation is designed around these baseline checks:

- A first-time user sees a clear empty state and an instruction for adding a task.
- Primary actions live where users expect them: completion on the left and settings on the right.
- Each task action has an accessibility label, including the completion area and task-details cog.
- System controls and font styles support Dynamic Type. At accessibility text sizes the bottom bar uses icons with full VoiceOver labels and the system large-content viewer.
- The navigation circle is 60 points wide; tab targets are at least 44 points. VoiceOver keeps the bar expanded.
- Reduce Motion uses a short transition for navigation; Reduce Transparency uses an opaque bar surface.
- Notification permission is only requested after someone explicitly enables notifications for a task.
- Completion and reminder changes are reversible: a completed task can be marked incomplete, and a reminder can be disabled. Deletion requires confirmation.

Before calling this production-ready, test it with VoiceOver, larger accessibility text sizes, Reduce Motion, different device sizes, and people who are unfamiliar with the app. Real usability feedback should determine the next iteration.

## Learning goals

The code intentionally leaves room for exploration rather than hiding everything behind frameworks. Good next experiments include:

1. Move tasks between groups by dragging (planned for 0.3.0).
2. Add a due date to `TaskItem`.
3. Support task filters without losing the simple default screen.
4. Add unit tests for persistence and notification scheduling decisions.
5. Test and improve VoiceOver focus order and extra-large Dynamic Type layouts.

## Working with Git

The repository keeps source code, the Xcode project, shared schemes, and project documentation. It intentionally ignores `InternalDocs/`, local Xcode user data, and build artifacts.

Use small, imperative commit messages that describe one change:

```text
Initial SwiftUI planning app
Add task deletion flow
Improve VoiceOver task actions
Schedule weekly task reminders
```

For feature work, start from an up-to-date default branch and use a focused branch:

```bash
git switch main
git pull --ff-only
git switch -c feature/task-deletion
```

Keep each branch centered on one user-facing improvement, verify it on a simulator or device, then commit the finished change.

## Status

This is an early, usable foundation—not a finished production app. Bugs, rough edges, and incomplete accessibility coverage are expected at this stage and are useful signals for the next learning-focused iteration.
