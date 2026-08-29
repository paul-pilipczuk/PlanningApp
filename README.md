# PlanningApp

A small, fully offline planning app for iPhone, built in SwiftUI.

PlanningApp is a learning project with a practical goal: create a calm, low-friction task experience that works well for people with different levels of technical confidence and different ways of interacting with their phone. It favors obvious actions, familiar system controls, readable dark-mode presentation, and device-local privacy over feature density.

## Product principles

- **Make the next action obvious.** Empty space adds a plan, the left bubble completes it, the task name edits it, and the trailing cog configures reminders.
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
| Enter a task name and tap **Add** | Saves a task on the device |
| Tap the bubble on the left | Marks the task complete or incomplete |
| Tap a task name | Opens a rename sheet |
| Tap the cog on the right | Opens that task’s reminder settings |
| Enable notifications | Chooses daily or weekly timing, a time of day, and whether to repeat until completion |

Completed tasks use a visible checkmark, strikethrough text, and reduced emphasis. Completing a task cancels its pending reminder. Marking it incomplete schedules the reminder again if it remains enabled.

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
│   └── TaskItem.swift                 # Task and reminder data
├── Services/
│   ├── NotificationManager.swift      # Local notification scheduling
│   └── TaskStore.swift                # On-device JSON persistence
├── Views/
│   ├── AddTaskView.swift              # Create-task sheet
│   ├── NotificationSettingsView.swift # Reminder configuration
│   ├── RenameTaskView.swift           # Rename-task sheet
│   └── TaskListView.swift             # Main planning screen
└── PlanningApp.swift                   # App entry point
```

Additional project documents:

- `IMPLEMENTATION_PLAN.md` explains the original intentionally lean scope.
- `SWIFT_CONCEPTS.md` links key SwiftUI concepts to concrete files and lines of code.
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

1. Add deletion with a confirmation and notification cleanup.
2. Sort completed tasks to the bottom.
3. Add notes or a due date to `TaskItem`.
4. Support task categories or filters without losing the simple default screen.
5. Add unit tests for persistence and notification scheduling decisions.
6. Test and improve VoiceOver focus order and extra-large Dynamic Type layouts.

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
