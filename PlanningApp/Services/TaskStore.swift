import Combine
import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem]

    init() {
        tasks = Self.loadTasks()
    }

    var incompleteTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    var completedTasks: [TaskItem] {
        tasks.filter(\.isCompleted)
    }

    func add(title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        tasks.insert(TaskItem(title: trimmedTitle), at: 0)
        saveTasks()
    }

    func rename(taskID: UUID, to title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].title = trimmedTitle
        saveTasks()
    }

    func toggleCompletion(for taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].isCompleted.toggle()
        let task = tasks[index]
        saveTasks()

        Task {
            if task.isCompleted {
                NotificationManager.shared.cancel(for: task.id)
            } else {
                await NotificationManager.shared.schedule(for: task)
            }
        }
    }

    func updateReminder(_ reminder: ReminderSettings, for taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].reminder = reminder
        let task = tasks[index]
        saveTasks()

        Task {
            await NotificationManager.shared.schedule(for: task)
        }
    }

    @discardableResult
    func move(taskID: UUID, before destinationID: UUID) -> Bool {
        guard taskID != destinationID,
              let sourceIndex = tasks.firstIndex(where: { $0.id == taskID }) else {
            return false
        }

        let previousOrder = tasks.map(\.id)
        let task = tasks.remove(at: sourceIndex)
        guard let destinationIndex = tasks.firstIndex(where: { $0.id == destinationID }) else {
            tasks.insert(task, at: sourceIndex)
            return false
        }

        tasks.insert(task, at: destinationIndex)
        guard tasks.map(\.id) != previousOrder else { return false }
        saveTasks()
        return true
    }

    @discardableResult
    func moveToEnd(taskID: UUID) -> Bool {
        guard let sourceIndex = tasks.firstIndex(where: { $0.id == taskID }),
              let lastIncompleteID = incompleteTasks.last?.id,
              lastIncompleteID != taskID else {
            return false
        }

        let task = tasks.remove(at: sourceIndex)
        guard let destinationIndex = tasks.firstIndex(where: { $0.id == lastIncompleteID }) else {
            tasks.insert(task, at: sourceIndex)
            return false
        }

        tasks.insert(task, at: destinationIndex + 1)
        saveTasks()
        return true
    }

    private static func loadTasks() -> [TaskItem] {
        guard let data = try? Data(contentsOf: storageURL),
              let tasks = try? JSONDecoder().decode([TaskItem].self, from: data) else {
            return []
        }
        return tasks
    }

    private func saveTasks() {
        do {
            try FileManager.default.createDirectory(
                at: Self.storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            return
        }
    }

    private static var storageURL: URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return directory.appendingPathComponent("PlanningApp/tasks.json")
    }
}
