import Combine
import Foundation

@MainActor
protocol TaskNotificationScheduling: AnyObject {
    func schedule(for task: TaskItem) async
    func cancel(for taskID: UUID)
}

extension NotificationManager: TaskNotificationScheduling {}

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var groups: [TaskGroup]
    @Published private(set) var hasLoadFailure = false
    @Published private(set) var errorMessage: String?
    @Published var feedbackMessage: String?

    private let storageURL: URL?
    private let notifications: (any TaskNotificationScheduling)?
    private let now: () -> Date
    private let write: (Data, URL) throws -> Void
    private var savedData: PlanningData
    private var reminderOperations: [UUID: Task<Void, Never>] = [:]
    var isSampleData: Bool { storageURL == nil }

    convenience init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sample-data") {
            do {
                var samples = try SampleTaskData.load()
                if ProcessInfo.processInfo.arguments.contains("-short-completed-data") {
                    samples.tasks = Array(samples.tasks.filter { $0.isCompleted && !$0.isArchived }.prefix(3))
                }
                self.init(sampleData: samples)
            }
            catch { preconditionFailure("SampleTasks.json must be bundled and valid: \(error)") }
            return
        }
        #endif
        self.init(storageURL: Self.defaultStorageURL)
    }

    init(storageURL: URL, notifications: (any TaskNotificationScheduling)? = NotificationManager.shared,
         now: @escaping () -> Date = Date.init,
         write: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.storageURL = storageURL
        self.notifications = notifications
        self.now = now
        self.write = write
        tasks = []
        groups = []
        savedData = PlanningData(tasks: [], groups: [])
        reload()
    }

    /// Demo sessions cannot write task files or touch real reminders.
    init(sampleData: PlanningData) {
        storageURL = nil
        notifications = nil
        now = Date.init
        write = { _, _ in }
        tasks = sampleData.tasks
        groups = sampleData.groups
        savedData = sampleData
    }

    var incompleteTasks: [TaskItem] { tasks.filter { !$0.isCompleted && !$0.isArchived } }
    var completedTasks: [TaskItem] { tasks.filter { $0.isCompleted && !$0.isArchived } }
    var archivedTasks: [TaskItem] {
        tasks.enumerated().filter { $0.element.isArchived }.sorted {
            let first = $0.element.archivedAt ?? .distantPast
            let second = $1.element.archivedAt ?? .distantPast
            return first == second ? $0.offset < $1.offset : first > second
        }.map(\.element)
    }

    var activeSections: [TaskSection] {
        var grouped: [UUID: [TaskItem]] = [:]
        grouped.reserveCapacity(groups.count)
        let knownGroups = Set(groups.map(\.id))
        var general: [TaskItem] = []
        for task in tasks where !task.isCompleted && !task.isArchived {
            if let groupID = task.groupID, knownGroups.contains(groupID) {
                grouped[groupID, default: []].append(task)
            } else { general.append(task) }
        }
        let named = groups.map { TaskSection(group: $0, tasks: grouped[$0.id] ?? []) }
        return named + (general.isEmpty ? [] : [TaskSection(group: nil, tasks: general)])
    }

    func groupName(for task: TaskItem) -> String {
        groups.first { $0.id == task.groupID }?.name ?? "General"
    }

    @discardableResult
    func add(title: String, description: String, groupID: UUID?, reminder: ReminderSettings) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        let task = TaskItem(title: title, description: description.trimmingCharacters(in: .whitespacesAndNewlines), groupID: groupID, reminder: reminder)
        var candidate = tasks
        if let last = incompleteTasks.last(where: { $0.groupID == groupID }), let index = candidate.firstIndex(where: { $0.id == last.id }) {
            candidate.insert(task, at: index + 1)
        } else { candidate.insert(task, at: 0) }
        guard commit(candidate, groups: groups) else { return false }
        reconcileReminder(for: task.id)
        return true
    }

    @discardableResult
    func update(taskID: UUID, title: String, description: String, groupID: UUID?, reminder: ReminderSettings) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = tasks.firstIndex(where: { $0.id == taskID }), !tasks[index].isArchived else { return false }
        var candidate = tasks
        candidate[index].title = title
        candidate[index].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate[index].groupID = groupID
        candidate[index].reminder = reminder
        guard commit(candidate, groups: groups) else { return false }
        reconcileReminder(for: taskID)
        return true
    }

    func createGroup(named name: String) -> TaskGroup? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !groups.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        let group = TaskGroup(name: name)
        return commit(tasks, groups: groups + [group]) ? group : nil
    }

    @discardableResult
    func delete(taskID: UUID) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return false }
        guard commit(tasks.filter { $0.id != taskID }, groups: groups) else { return false }
        reconcileReminder(for: taskID)
        feedbackMessage = "Permanently deleted “\(task.title)”."
        return true
    }

    @discardableResult
    func archive(taskID: UUID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].isCompleted, !tasks[index].isArchived else { return false }
        var candidate = tasks
        candidate[index].archivedAt = now()
        guard commit(candidate, groups: groups) else { return false }
        reconcileReminder(for: taskID)
        feedbackMessage = "Archived “\(candidate[index].title)”. You can restore it from Archived."
        return true
    }

    @discardableResult
    func restore(taskID: UUID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].isArchived else { return false }
        var candidate = tasks
        candidate[index].archivedAt = nil
        candidate[index].isCompleted = true
        guard commit(candidate, groups: groups) else { return false }
        reconcileReminder(for: taskID)
        feedbackMessage = "Restored “\(candidate[index].title)” to Completed."
        return true
    }

    @discardableResult
    func toggleCompletion(for taskID: UUID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }), !tasks[index].isArchived else { return false }
        var candidate = tasks
        candidate[index].isCompleted.toggle()
        guard commit(candidate, groups: groups) else { return false }
        reconcileReminder(for: taskID)
        return true
    }

    @discardableResult
    func move(taskID: UUID, before destinationID: UUID, persist: Bool = true) -> Bool {
        guard !hasLoadFailure, taskID != destinationID,
              let source = tasks.firstIndex(where: { $0.id == taskID }),
              let destination = tasks.firstIndex(where: { $0.id == destinationID }),
              !tasks[source].isCompleted, !tasks[source].isArchived,
              !tasks[destination].isCompleted, !tasks[destination].isArchived,
              tasks[source].groupID == tasks[destination].groupID else { return false }
        var candidate = tasks
        let task = candidate.remove(at: source)
        guard let index = candidate.firstIndex(where: { $0.id == destinationID }) else { return false }
        candidate.insert(task, at: index)
        if persist { return commit(candidate, groups: groups) }
        tasks = candidate
        return true
    }

    @discardableResult
    func moveToEnd(taskID: UUID, persist: Bool = true) -> Bool {
        guard !hasLoadFailure, let source = tasks.firstIndex(where: { $0.id == taskID }),
              !tasks[source].isCompleted, !tasks[source].isArchived else { return false }
        let task = tasks[source]
        guard let last = incompleteTasks.last(where: { $0.groupID == task.groupID }), last.id != taskID else { return false }
        var candidate = tasks
        candidate.remove(at: source)
        guard let index = candidate.firstIndex(where: { $0.id == last.id }) else { return false }
        candidate.insert(task, at: index + 1)
        if persist { return commit(candidate, groups: groups) }
        tasks = candidate
        return true
    }

    @discardableResult
    func persistTaskOrder() -> Bool {
        guard commit(tasks, groups: groups) else {
            tasks = savedData.tasks
            groups = savedData.groups
            return false
        }
        return true
    }

    func dismissError() { if !hasLoadFailure { errorMessage = nil } }

    func reload() {
        guard let storageURL else { return }
        do {
            let data = try Self.load(from: storageURL)
            tasks = data.tasks
            groups = data.groups
            savedData = data
            hasLoadFailure = false
            errorMessage = nil
        } catch {
            hasLoadFailure = true
            errorMessage = "Your saved plans couldn’t be opened. The existing file has been left untouched. \(error.localizedDescription)"
        }
    }

    private func commit(_ candidate: [TaskItem], groups candidateGroups: [TaskGroup]) -> Bool {
        guard !hasLoadFailure else { return false }
        let snapshot = PlanningData(tasks: candidate, groups: candidateGroups)
        do {
            if let storageURL {
                let bytes = try JSONEncoder().encode(snapshot)
                try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try write(bytes, storageURL)
            }
            if tasks != candidate { tasks = candidate }
            if groups != candidateGroups { groups = candidateGroups }
            savedData = snapshot
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Your change couldn’t be saved. Your saved plans are unchanged. Please try again."
            return false
        }
    }

    private func reconcileReminder(for id: UUID) {
        let previous = reminderOperations.removeValue(forKey: id)
        previous?.cancel()
        guard let notifications else { return }
        guard let task = tasks.first(where: { $0.id == id }), !task.isCompleted, !task.isArchived, task.reminder.isEnabled else {
            notifications.cancel(for: id)
            return
        }
        // Finish a cancelled operation before replacing this task's request.
        reminderOperations[id] = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled, let current = self?.tasks.first(where: { $0.id == id }), current == task else { return }
            await notifications.schedule(for: current)
        }
    }

    private static func load(from url: URL) throws -> PlanningData {
        let bytes: Data
        do { bytes = try Data(contentsOf: url) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return PlanningData(tasks: [], groups: [])
        }
        let decoder = JSONDecoder()
        let data: PlanningData
        if let container = try? decoder.decode(PlanningData.self, from: bytes) {
            guard (1...3).contains(container.version) else { throw StorageFailure.unsupportedVersion }
            data = container
        } else {
            data = PlanningData(tasks: try decoder.decode([TaskItem].self, from: bytes), groups: [])
        }
        guard Set(data.tasks.map(\.id)).count == data.tasks.count,
              Set(data.groups.map(\.id)).count == data.groups.count,
              data.tasks.allSatisfy({ !$0.isArchived || $0.isCompleted }) else { throw StorageFailure.invalidData }
        return data
    }

    private enum StorageFailure: LocalizedError {
        case unsupportedVersion, invalidData
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "This file needs a newer version of Planning."
            case .invalidData: "The file contains inconsistent task data."
            }
        }
    }

    private static var defaultStorageURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PlanningApp/tasks.json")
    }
}
