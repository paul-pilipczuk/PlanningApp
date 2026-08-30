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

Completed tasks use a visible checkmark, strikethrough text, and reduced emphasis. They are collected in a sticky, collapsible **Completed** overlay at the bottom of the list. When expanded, it uses up to half of the display without moving the Tasks list. Completing a task cancels its pending reminder. Marking it incomplete schedules the reminder again if it remains enabled.

## Privacy and reminders

All task data is stored locally as JSON in the app’s Application Support directory. The app does not send task content off the phone.

Reminders use `UNUserNotificationCenter`, Apple’s local-notification API. When notifications are enabled for a task, iOS asks for permission. A daily reminder repeats each day at the selected time; a weekly reminder repeats on the chosen weekday and time. If **Repeat until done** is turned off, only the next matching notification is scheduled.

Because notifications are local, test them on a physical iPhone as well as the Simulator. Delivery timing and notification permission are ultimately controlled by iOS.

## Requirements

- macOS with Xcode 15 or later
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
│   └── TaskItem.swift                 # Task, group, and reminder data
├── Services/
│   ├── NotificationManager.swift      # Local notification scheduling
│   └── TaskStore.swift                # On-device JSON persistence
├── Views/
│   ├── AddTaskView.swift              # Unified create/details editor
│   └── TaskListView.swift             # Main planning screen
└── PlanningApp.swift                   # App entry point
```

Additional project documents:

- `InternalDocs/IMPLEMENTATION_PLAN.md` explains the original intentionally lean scope.
- `InternalDocs/SWIFT_CONCEPTS.md` links key SwiftUI concepts to concrete files and lines of code.
- `InternalDocs/` is local-only working documentation and is intentionally excluded from Git.

## Architecture

The app deliberately keeps its architecture simple:

- `TaskItem` and `ReminderSettings` are small `Codable` value types.
- `TaskStore` is the single observable source of task state. It loads data when the app starts and saves after each user change.
- SwiftUI views receive the store through `@EnvironmentObject` and keep sheet presentation state locally with `@State`.
- `NotificationManager` owns notification permission, scheduling, and cancellation, keeping platform APIs out of the views.

The app currently uses a dark-mode-first appearance with `preferredColorScheme(.dark)`. It is intentionally a focused iPhone experience rather than a broad, multi-platform product.

## UX and accessibility checklist

The current implementation is designed around these baseline checks:

- A first-time user sees a clear empty state and an instruction for adding a task.
- Primary actions live where users expect them: completion on the left and settings on the right.
- Each task action has an accessibility label, including the completion bubble, rename action, and notification cog.
- The system’s standard controls and font styles inherit much of iOS’s accessibility behavior, including Dynamic Type support.
- Notification permission is only requested after someone explicitly enables notifications for a task.
- Every key task action is reversible: a completed task can be marked incomplete, and a reminder can be disabled.

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
