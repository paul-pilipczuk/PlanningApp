import Combine
import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var groups: [TaskGroup]

    init() {
        let data = Self.loadData()
        tasks = data.tasks
        groups = data.groups
    }

    var incompleteTasks: [TaskItem] { tasks.filter { !$0.isCompleted } }
    var completedTasks: [TaskItem] { tasks.filter(\.isCompleted) }

    var activeSections: [TaskSection] {
        let named = groups.map { group in
            TaskSection(group: group, tasks: incompleteTasks.filter { $0.groupID == group.id })
        }
        let general = incompleteTasks.filter { $0.groupID == nil }
        return named + (general.isEmpty ? [] : [TaskSection(group: nil, tasks: general)])
    }

    func add(title: String, description: String, groupID: UUID?, reminder: ReminderSettings) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let task = TaskItem(title: title, description: description.trimmingCharacters(in: .whitespacesAndNewlines), groupID: groupID, reminder: reminder)
        insert(task, in: groupID)
        saveData()
        Task { await NotificationManager.shared.schedule(for: task) }
    }

    func update(taskID: UUID, title: String, description: String, groupID: UUID?, reminder: ReminderSettings) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].title = title
        tasks[index].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[index].groupID = groupID
        tasks[index].reminder = reminder
        let task = tasks[index]
        saveData()
        Task { await NotificationManager.shared.schedule(for: task) }
    }

    func createGroup(named name: String) -> TaskGroup? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !groups.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        let group = TaskGroup(name: name)
        groups.append(group)
        saveData()
        return group
    }

    func delete(taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let task = tasks.remove(at: index)
        saveData()
        NotificationManager.shared.cancel(for: task.id)
    }

    func toggleCompletion(for taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].isCompleted.toggle()
        let task = tasks[index]
        saveData()
        Task {
            if task.isCompleted { NotificationManager.shared.cancel(for: task.id) }
            else { await NotificationManager.shared.schedule(for: task) }
        }
    }

    @discardableResult
    func move(taskID: UUID, before destinationID: UUID, persist: Bool = true) -> Bool {
        guard taskID != destinationID,
              let source = tasks.firstIndex(where: { $0.id == taskID }),
              let destination = tasks.firstIndex(where: { $0.id == destinationID }),
              !tasks[source].isCompleted,
              tasks[source].groupID == tasks[destination].groupID else { return false }
        let task = tasks.remove(at: source)
        let index = tasks.firstIndex(where: { $0.id == destinationID })!
        tasks.insert(task, at: index)
        if persist { saveData() }
        return true
    }

    @discardableResult
    func moveToEnd(taskID: UUID, persist: Bool = true) -> Bool {
        guard let source = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        let task = tasks[source]
        guard let last = incompleteTasks.last(where: { $0.groupID == task.groupID }), last.id != taskID else { return false }
        tasks.remove(at: source)
        let index = tasks.firstIndex(where: { $0.id == last.id })!
        tasks.insert(task, at: index + 1)
        if persist { saveData() }
        return true
    }

    func persistTaskOrder() {
        saveData()
    }

    private func insert(_ task: TaskItem, in groupID: UUID?) {
        if let last = incompleteTasks.last(where: { $0.groupID == groupID }), let index = tasks.firstIndex(where: { $0.id == last.id }) {
            tasks.insert(task, at: index + 1)
        } else {
            tasks.insert(task, at: 0)
        }
    }

    private static func loadData() -> PlanningData {
        guard let data = try? Data(contentsOf: storageURL) else { return PlanningData(tasks: [], groups: []) }
        if let planningData = try? JSONDecoder().decode(PlanningData.self, from: data) { return planningData }
        if let legacyTasks = try? JSONDecoder().decode([TaskItem].self, from: data) { return PlanningData(tasks: legacyTasks, groups: []) }
        return PlanningData(tasks: [], groups: [])
    }

    private func saveData() {
        do {
            try FileManager.default.createDirectory(at: Self.storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(PlanningData(tasks: tasks, groups: groups))
            try data.write(to: Self.storageURL, options: .atomic)
        } catch { }
    }

    private static var storageURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PlanningApp/tasks.json")
    }
}
