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
    @Published private(set) var tasks: [TaskItem] {
        didSet {
            invalidateTaskCollections()
            taskRevision &+= 1
        }
    }
    @Published private(set) var groups: [TaskGroup] {
        didSet {
            cachedSections = nil
            cachedActiveRows = nil
            cachedGroupNames = nil
            cachedActiveGroups.removeAll(keepingCapacity: false)
        }
    }
    @Published private(set) var progressConfiguration: ProgressConfiguration {
        didSet {
            cachedSections = nil
            cachedActiveRows = nil
            cachedActiveGroups.removeAll(keepingCapacity: false)
            cachedProgressMarkers = nil
            cachedProgressPositions = nil
            taskRevision &+= 1
        }
    }
    // Published tasks already invalidate their readers; this token adds no publication.
    private(set) var taskRevision: UInt64 = 0
    @Published private(set) var hasLoadFailure = false
    @Published private(set) var errorMessage: String?
    @Published var feedbackMessage: String?

    private let storageURL: URL?
    private let notifications: (any TaskNotificationScheduling)?
    private let now: () -> Date
    private let write: (Data, URL) throws -> Void
    private var savedData: PlanningData
    private var reminderOperations: [UUID: Task<Void, Never>] = [:]
    // Lazy, replaceable projections of current data, never a history of snapshots.
    private var cachedIncomplete: [TaskItem]?
    private var cachedCompleted: [TaskItem]?
    private var cachedArchived: [TaskItem]?
    private var cachedSections: [TaskSection]?
    private var cachedActiveRows: [ActiveTaskRow]?
    private struct ActiveLane: Hashable {
        let groupID: UUID?
        let markerID: UUID?
        var usesDisplayedGroup = false
    }
    private var cachedActiveGroups: [ActiveLane: [TaskItem]] = [:]
    private var cachedProgressMarkers: [UUID: ProgressMarker]?
    private var cachedProgressPositions: [UUID: Int]?
    private var cachedGroupNames: [UUID: String]?
    var isSampleData: Bool { storageURL == nil }

    convenience init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sample-data") {
            do {
                var samples = try SampleTaskData.load()
                if ProcessInfo.processInfo.arguments.contains("-progress-data") {
                    let active = samples.tasks.filter { !$0.isCompleted && !$0.isArchived }.prefix(2)
                    let completed = samples.tasks.filter { $0.isCompleted && !$0.isArchived }.prefix(1)
                    let archived = samples.tasks.filter(\.isArchived).prefix(1)
                    samples.tasks = Array(active) + Array(completed) + Array(archived)
                }
                if ProcessInfo.processInfo.arguments.contains("-orphaned-data"),
                   let index = samples.tasks.firstIndex(where: { !$0.isCompleted && !$0.isArchived }) {
                    samples.tasks[index].groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
                    samples.tasks[index].progressMarkerID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
                    samples.progressConfiguration.isEnabled = ProcessInfo.processInfo.arguments.contains("-progress-enabled")
                }
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
        progressConfiguration = ProgressConfiguration()
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
        progressConfiguration = sampleData.progressConfiguration
        savedData = sampleData
    }

    var incompleteTasks: [TaskItem] {
        if let cachedIncomplete { return cachedIncomplete }
        let result = tasks.filter { !$0.isCompleted && !$0.isArchived }
        cachedIncomplete = result
        return result
    }

    var completedTasks: [TaskItem] {
        if let cachedCompleted { return cachedCompleted }
        let result = tasks.filter { $0.isCompleted && !$0.isArchived }
        cachedCompleted = result
        return result
    }

    var archivedTasks: [TaskItem] {
        if let cachedArchived { return cachedArchived }
        let result = tasks.enumerated().filter { $0.element.isArchived }.sorted {
            let first = $0.element.archivedAt ?? .distantPast
            let second = $1.element.archivedAt ?? .distantPast
            return first == second ? $0.offset < $1.offset : first > second
        }.map(\.element)
        cachedArchived = result
        return result
    }

    var activeSections: [TaskSection] {
        if let cachedSections { return cachedSections }
        var grouped: [UUID: [TaskItem]] = [:]
        grouped.reserveCapacity(groups.count)
        let knownGroups = Set(groups.map(\.id))
        var general: [TaskItem] = []
        for task in incompleteTasks {
            if let groupID = task.groupID, knownGroups.contains(groupID) {
                grouped[groupID, default: []].append(task)
            } else { general.append(task) }
        }
        let named = groups.map { makeSection(group: $0, tasks: grouped[$0.id] ?? []) }
        let result = named + (general.isEmpty ? [] : [makeSection(group: nil, tasks: general)])
        cachedSections = result
        return result
    }

    var activeRows: [ActiveTaskRow] {
        if let cachedActiveRows { return cachedActiveRows }
        var rows: [ActiveTaskRow] = []
        rows.reserveCapacity(incompleteTasks.count + groups.count + 1)
        for section in activeSections {
            rows.append(.group(section.group, isEmpty: section.tasks.isEmpty))
            if progressConfiguration.isEnabled {
                for progress in section.progressSections {
                    rows.append(.progress(groupID: section.id, marker: progress.marker, isEmpty: progress.tasks.isEmpty))
                    for task in progress.tasks { rows.append(.task(task)) }
                }
            } else {
                for task in section.tasks { rows.append(.task(task)) }
            }
        }
        if !activeSections.contains(where: { $0.group == nil }) { rows.append(.group(nil, isEmpty: true)) }
        cachedActiveRows = rows
        return rows
    }

    /// Raw group membership retains the existing group-local reorder contract,
    /// including tasks whose group no longer exists and display under General.
    func activeTasks(in groupID: UUID?, progressMarkerID: UUID? = nil) -> [TaskItem] {
        let markerID = progressConfiguration.isEnabled ? progressMarkerID : nil
        let lane = ActiveLane(groupID: groupID, markerID: markerID)
        if let cached = cachedActiveGroups[lane] { return cached }
        let filtered = incompleteTasks.filter {
            $0.groupID == groupID && (markerID == nil || progressMarker(for: $0).id == markerID)
        }
        let result = markerID == nil ? orderedByProgress(filtered) : filtered
        // Retain only lanes represented in current active data, bounding arbitrary queries.
        if !result.isEmpty { cachedActiveGroups[lane] = result }
        return result
    }

    /// General includes supported saved tasks whose original group is missing.
    /// Cache this displayed lane separately from the raw-group reorder contract.
    func displayedActiveTasks(in groupID: UUID?, progressMarkerID: UUID? = nil) -> [TaskItem] {
        if let groupID {
            guard groupNamesByID[groupID] != nil else { return [] }
            return activeTasks(in: groupID, progressMarkerID: progressMarkerID)
        }
        let markerID = progressConfiguration.isEnabled ? progressMarkerID : nil
        let lane = ActiveLane(groupID: nil, markerID: markerID, usesDisplayedGroup: true)
        if let cached = cachedActiveGroups[lane] { return cached }
        let filtered = incompleteTasks.filter {
            displayGroupID(for: $0) == nil && (markerID == nil || progressMarker(for: $0).id == markerID)
        }
        let result = markerID == nil ? orderedByProgress(filtered) : filtered
        if !result.isEmpty { cachedActiveGroups[lane] = result }
        return result
    }

    func displayGroupID(for task: TaskItem) -> UUID? {
        guard let id = task.groupID, groupNamesByID[id] != nil else { return nil }
        return id
    }

    func progressMarker(for task: TaskItem) -> ProgressMarker {
        if let id = task.progressMarkerID, let marker = progressMarkersByID[id] { return marker }
        return progressConfiguration.markers[0]
    }

    func progressFraction(for task: TaskItem) -> Double {
        if task.isCompleted { return 1 }
        if cachedProgressPositions == nil {
            cachedProgressPositions = Dictionary(uniqueKeysWithValues: progressConfiguration.markers.enumerated().map { ($0.element.id, $0.offset) })
        }
        let index = cachedProgressPositions?[progressMarker(for: task).id] ?? 0
        return Double(index) / Double(progressConfiguration.markers.count)
    }

    private var progressMarkersByID: [UUID: ProgressMarker] {
        if let cachedProgressMarkers { return cachedProgressMarkers }
        let result = Dictionary(uniqueKeysWithValues: progressConfiguration.markers.map { ($0.id, $0) })
        cachedProgressMarkers = result
        return result
    }

    private func makeSection(group: TaskGroup?, tasks: [TaskItem]) -> TaskSection {
        guard progressConfiguration.isEnabled, !tasks.isEmpty else { return TaskSection(group: group, tasks: tasks) }
        let sections = progressSections(for: tasks)
        return TaskSection(group: group, tasks: sections.flatMap(\.tasks), progressSections: sections)
    }

    /// Stable buckets preserve manual ordering without sorting tasks on each render.
    private func progressSections(for tasks: [TaskItem]) -> [TaskProgressSection] {
        let lookup = progressMarkersByID
        let firstID = progressConfiguration.markers[0].id
        var buckets: [UUID: [TaskItem]] = [:]
        for task in tasks {
            let id = task.progressMarkerID.flatMap { lookup[$0]?.id } ?? firstID
            buckets[id, default: []].append(task)
        }
        return progressConfiguration.markers.map { TaskProgressSection(marker: $0, tasks: buckets[$0.id] ?? []) }
    }

    private func orderedByProgress(_ tasks: [TaskItem]) -> [TaskItem] {
        guard progressConfiguration.isEnabled, !tasks.isEmpty else { return tasks }
        return progressSections(for: tasks).flatMap(\.tasks)
    }

    @discardableResult
    func setProgressEnabled(_ enabled: Bool) -> Bool {
        var candidate = progressConfiguration
        candidate.isEnabled = enabled
        return updateProgressConfiguration(candidate)
    }

    @discardableResult
    func updateProgressConfiguration(_ configuration: ProgressConfiguration) -> Bool {
        guard configuration.isValid else {
            errorMessage = "Keep at least one progress label with a unique, nonempty name."
            return false
        }
        guard configuration != progressConfiguration else { return !hasLoadFailure }
        let retainedIDs = Set(configuration.markers.map(\.id))
        let firstID = configuration.markers[0].id
        let candidate = tasks.map { task in
            var updated = task
            let previousID = progressMarker(for: task).id
            updated.progressMarkerID = retainedIDs.contains(previousID) ? previousID : firstID
            return updated
        }
        return commit(candidate, groups: groups, progress: configuration)
    }

    @discardableResult
    func setProgress(taskID: UUID, markerID: UUID) -> Bool {
        guard progressConfiguration.isEnabled, progressMarkersByID[markerID] != nil,
              let index = tasks.firstIndex(where: { $0.id == taskID }),
              !tasks[index].isCompleted, !tasks[index].isArchived else { return false }
        if tasks[index].progressMarkerID == markerID { return !hasLoadFailure }
        var candidate = tasks
        candidate[index].progressMarkerID = markerID
        return commit(candidate, groups: groups)
    }

    func groupName(for task: TaskItem) -> String {
        guard let groupID = task.groupID else { return "General" }
        return groupNamesByID[groupID] ?? "General"
    }

    private var groupNamesByID: [UUID: String] {
        if cachedGroupNames == nil {
            cachedGroupNames = Dictionary(groups.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        }
        return cachedGroupNames ?? [:]
    }

    /// Memory pressure may discard all projections without changing saved state
    /// or asking SwiftUI to redraw; the next read rebuilds only what it needs.
    func releasePresentationCaches() {
        invalidateTaskCollections()
        cachedGroupNames = nil
        cachedProgressMarkers = nil
        cachedProgressPositions = nil
    }

    private func invalidateTaskCollections() {
        cachedIncomplete = nil
        cachedCompleted = nil
        cachedArchived = nil
        cachedSections = nil
        cachedActiveRows = nil
        cachedActiveGroups.removeAll(keepingCapacity: false)
    }

    @discardableResult
    func add(title: String, description: String, groupID: UUID?, reminder: ReminderSettings, progressMarkerID: UUID? = nil) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        if let progressMarkerID, progressMarkersByID[progressMarkerID] == nil { return false }
        let task = TaskItem(title: title, description: description.trimmingCharacters(in: .whitespacesAndNewlines), groupID: groupID, reminder: reminder,
                            progressMarkerID: progressMarkerID ?? progressConfiguration.markers[0].id)
        var candidate = tasks
        if let last = incompleteTasks.last(where: { $0.groupID == groupID }), let index = candidate.firstIndex(where: { $0.id == last.id }) {
            candidate.insert(task, at: index + 1)
        } else { candidate.insert(task, at: 0) }
        guard commit(candidate, groups: groups) else { return false }
        reconcileReminder(for: task.id)
        return true
    }

    @discardableResult
    func update(taskID: UUID, title: String, description: String, groupID: UUID?, reminder: ReminderSettings, progressMarkerID: UUID? = nil) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = tasks.firstIndex(where: { $0.id == taskID }), !tasks[index].isArchived else { return false }
        let needsReminderUpdate = tasks[index].title != title || tasks[index].reminder != reminder
        var candidate = tasks
        candidate[index].title = title
        candidate[index].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate[index].groupID = groupID
        candidate[index].reminder = reminder
        if let progressMarkerID {
            guard progressMarkersByID[progressMarkerID] != nil else { return false }
            candidate[index].progressMarkerID = progressMarkerID
        }
        guard commit(candidate, groups: groups) else { return false }
        if needsReminderUpdate { reconcileReminder(for: taskID) }
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
        guard tasks.contains(where: { $0.id == taskID }) else { return false }
        guard commit(tasks.filter { $0.id != taskID }, groups: groups) else { return false }
        reconcileReminder(for: taskID)
        feedbackMessage = "Task deleted"
        return true
    }

    @discardableResult
    func archive(taskID: UUID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].isCompleted, !tasks[index].isArchived else { return false }
        var candidate = tasks
        candidate[index].archivedAt = now()
        guard commit(candidate, groups: groups) else { return false }
        reconcileReminder(for: taskID)
        feedbackMessage = "Moved to Archived"
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
        feedbackMessage = "Moved to Completed"
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
        var task = candidate.remove(at: source)
        if progressConfiguration.isEnabled { task.progressMarkerID = progressMarker(for: tasks[destination]).id }
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
        var task = tasks[source]
        guard let last = activeTasks(in: task.groupID).last, last.id != taskID else { return false }
        if progressConfiguration.isEnabled { task.progressMarkerID = progressMarker(for: last).id }
        var candidate = tasks
        candidate.remove(at: source)
        guard let index = candidate.firstIndex(where: { $0.id == last.id }) else { return false }
        candidate.insert(task, at: index + 1)
        if persist { return commit(candidate, groups: groups) }
        tasks = candidate
        return true
    }

    /// An explicit section drop changes progress and order in the same candidate save.
    @discardableResult
    func move(taskID: UUID, toProgressMarker markerID: UUID, before destinationID: UUID? = nil, persist: Bool = true) -> Bool {
        guard progressConfiguration.isEnabled, let source = tasks.first(where: { $0.id == taskID }) else { return false }
        let groupID = groups.contains(where: { $0.id == source.groupID }) ? source.groupID : nil
        return move(taskID: taskID, toGroup: groupID, progressMarkerID: markerID, before: destinationID, persist: persist)
    }

    /// A group-heading drop retains progress; a progress-heading/row drop supplies its label.
    @discardableResult
    func move(taskID: UUID, toGroup groupID: UUID?, progressMarkerID: UUID? = nil, before destinationID: UUID? = nil, persist: Bool = true) -> Bool {
        guard !hasLoadFailure, groupID == nil || groups.contains(where: { $0.id == groupID }),
              let source = tasks.firstIndex(where: { $0.id == taskID }),
              !tasks[source].isCompleted, !tasks[source].isArchived else { return false }
        if let progressMarkerID, progressMarkersByID[progressMarkerID] == nil { return false }
        let markerID = progressMarkerID ?? (progressConfiguration.isEnabled ? progressMarker(for: tasks[source]).id : tasks[source].progressMarkerID)
        if let destinationID {
            guard destinationID != taskID,
                  let destination = tasks.first(where: { $0.id == destinationID }),
                  !destination.isCompleted, !destination.isArchived, displayGroupID(for: destination) == groupID,
                  !progressConfiguration.isEnabled || progressMarker(for: destination).id == markerID else { return false }
        }
        var candidate = tasks
        var task = candidate.remove(at: source)
        task.groupID = groupID
        task.progressMarkerID = markerID
        let insertionIndex: Int
        if let destinationID, let index = candidate.firstIndex(where: { $0.id == destinationID }) {
            insertionIndex = index
        } else if let last = candidate.lastIndex(where: {
            !$0.isCompleted && !$0.isArchived && displayGroupID(for: $0) == groupID &&
                (!progressConfiguration.isEnabled || progressMarker(for: $0).id == markerID)
        }) {
            insertionIndex = last + 1
        } else if let last = candidate.lastIndex(where: { !$0.isCompleted && !$0.isArchived && displayGroupID(for: $0) == groupID }) {
            insertionIndex = last + 1
        } else { insertionIndex = min(source, candidate.count) }
        guard insertionIndex != source || task.groupID != tasks[source].groupID || task.progressMarkerID != tasks[source].progressMarkerID else { return false }
        candidate.insert(task, at: insertionIndex)
        if persist { return commit(candidate, groups: groups) }
        tasks = candidate
        return true
    }

    @discardableResult
    func persistTaskOrder() -> Bool {
        guard commit(tasks, groups: groups) else {
            tasks = savedData.tasks
            groups = savedData.groups
            if progressConfiguration != savedData.progressConfiguration { progressConfiguration = savedData.progressConfiguration }
            return false
        }
        return true
    }

    /// Cancellation restores the latest durable state without saving a preview.
    func cancelTaskOrderChanges() {
        if tasks != savedData.tasks { tasks = savedData.tasks }
    }

    func dismissError() { if !hasLoadFailure { errorMessage = nil } }

    func reload() {
        guard let storageURL else { return }
        do {
            let data = try Self.load(from: storageURL)
            tasks = data.tasks
            groups = data.groups
            if progressConfiguration != data.progressConfiguration { progressConfiguration = data.progressConfiguration }
            savedData = data
            hasLoadFailure = false
            errorMessage = nil
        } catch {
            hasLoadFailure = true
            errorMessage = "Your saved plans couldn’t be opened. The existing file has been left untouched. \(error.localizedDescription)"
        }
    }

    private func commit(_ candidate: [TaskItem], groups candidateGroups: [TaskGroup], progress: ProgressConfiguration? = nil) -> Bool {
        guard !hasLoadFailure else { return false }
        let configuration = progress ?? progressConfiguration
        let snapshot = PlanningData(tasks: candidate, groups: candidateGroups, progressConfiguration: configuration)
        do {
            if let storageURL {
                let bytes = try JSONEncoder().encode(snapshot)
                try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try write(bytes, storageURL)
            }
            if tasks != candidate { tasks = candidate }
            if groups != candidateGroups { groups = candidateGroups }
            if progressConfiguration != configuration { progressConfiguration = configuration }
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
            guard !Task.isCancelled, let current = self?.tasks.first(where: { $0.id == id }), current.title == task.title,
                  current.reminder == task.reminder, current.isCompleted == task.isCompleted,
                  current.isArchived == task.isArchived else { return }
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
            guard (1...4).contains(container.version) else { throw StorageFailure.unsupportedVersion }
            data = container
        } else {
            data = PlanningData(tasks: try decoder.decode([TaskItem].self, from: bytes), groups: [])
        }
        guard Set(data.tasks.map(\.id)).count == data.tasks.count,
              Set(data.groups.map(\.id)).count == data.groups.count,
              data.progressConfiguration.isValid,
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
