import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func schedule(for task: TaskItem) async {
        cancel(for: task.id)

        guard !Task.isCancelled, task.reminder.isEnabled, !task.isCompleted, !task.isArchived else { return }
        guard await requestAuthorization(), !Task.isCancelled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task reminder"
        content.body = task.title
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        let trigger = makeTrigger(from: task.reminder)
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            guard !Task.isCancelled else { return }
            try await center.add(request)
            if Task.isCancelled { cancel(for: task.id) }
        } catch {
            return
        }
    }

    func cancel(for taskID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [taskID.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [taskID.uuidString])
    }

    private func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    private func makeTrigger(from settings: ReminderSettings) -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = settings.hour
        components.minute = settings.minute

        if settings.frequency == .weekly {
            components.weekday = settings.weekday
        }

        if settings.repeatsUntilCompleted {
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        let nextDate = nextDate(for: components)
        let nextComponents = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .weekday],
            from: nextDate
        )
        return UNCalendarNotificationTrigger(dateMatching: nextComponents, repeats: false)
    }

    private func nextDate(for components: DateComponents) -> Date {
        Calendar.current.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        ) ?? Date().addingTimeInterval(60)
    }
}
