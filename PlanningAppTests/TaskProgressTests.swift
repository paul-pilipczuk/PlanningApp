import Combine
import XCTest
@testable import PlanningApp

@MainActor
final class TaskProgressTests: XCTestCase {
    private let todo = ProgressConfiguration.defaultMarkers[0]
    private let doing = ProgressConfiguration.defaultMarkers[1]

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("tasks.json")
    }

    private func enabledStore(_ tasks: [TaskItem], groups: [TaskGroup] = []) -> TaskStore {
        TaskStore(sampleData: PlanningData(tasks: tasks, groups: groups,
                                         progressConfiguration: ProgressConfiguration(isEnabled: true)))
    }

    func testDefaultsAreOffWithTwoStableEditableLabels() {
        let first = ProgressConfiguration()
        XCTAssertFalse(first.isEnabled)
        XCTAssertEqual(first.markers.map(\.label), ["To do", "In progress"])
        XCTAssertEqual(first, ProgressConfiguration())
        XCTAssertTrue(first.isValid)
    }

    func testLegacyVersionThreeLoadsOffAndEnablingPreservesTaskFields() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let group = TaskGroup(name: "Work")
        let original = TaskItem(title: "Existing", description: "Keep me", groupID: group.id,
                                reminder: ReminderSettings(hour: 12, minute: 15, weekday: 4))
        let data = PlanningData(tasks: [original], groups: [group])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as? [String: Any])
        object["version"] = 3
        object.removeValue(forKey: "progressConfiguration")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        let store = TaskStore(storageURL: url, notifications: nil)
        XCTAssertFalse(store.hasLoadFailure)
        XCTAssertFalse(store.progressConfiguration.isEnabled)
        XCTAssertEqual(store.tasks, [original])
        XCTAssertTrue(store.setProgressEnabled(true))
        var expected = original
        expected.progressMarkerID = todo.id
        XCTAssertEqual(store.tasks, [expected])
        let reopened = TaskStore(storageURL: url, notifications: nil)
        XCTAssertTrue(reopened.progressConfiguration.isEnabled)
        XCTAssertEqual(reopened.tasks, [expected])
        XCTAssertEqual(try JSONDecoder().decode(PlanningData.self, from: Data(contentsOf: url)).version, 4)
    }

    func testStableProgressOrderAppliesWithinEachGroupAndGeneral() {
        let group = TaskGroup(name: "Work")
        let first = TaskItem(title: "Doing first", groupID: group.id, progressMarkerID: doing.id)
        let second = TaskItem(title: "Todo first", groupID: group.id, progressMarkerID: todo.id)
        let third = TaskItem(title: "Doing second", groupID: group.id, progressMarkerID: doing.id)
        let fourth = TaskItem(title: "Todo second", groupID: group.id, progressMarkerID: todo.id)
        let generalDoing = TaskItem(title: "General doing", progressMarkerID: doing.id)
        let generalTodo = TaskItem(title: "General todo")
        let store = enabledStore([first, second, third, fourth, generalDoing, generalTodo], groups: [group])
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [second.id, fourth.id, first.id, third.id])
        XCTAssertEqual(store.activeSections[1].tasks.map(\.id), [generalTodo.id, generalDoing.id])
        XCTAssertEqual(store.tasks.map(\.id), [first.id, second.id, third.id, fourth.id, generalDoing.id, generalTodo.id])
    }

    func testMissingProgressAndGroupReferencesRemainVisibleInGeneral() {
        let missing = TaskItem(title: "Missing references", groupID: UUID(), progressMarkerID: UUID())
        let store = enabledStore([missing])
        XCTAssertEqual(store.progressMarker(for: missing), todo)
        XCTAssertEqual(store.activeSections.first?.title, "General")
        XCTAssertEqual(store.activeSections.first?.tasks.map(\.id), [missing.id])
    }

    func testChangingProgressRefreshesWarmCollectionsAndPersistsWithoutCompleting() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(storageURL: url, notifications: nil)
        XCTAssertTrue(store.add(title: "First", description: "", groupID: nil, reminder: ReminderSettings()))
        XCTAssertTrue(store.add(title: "Second", description: "", groupID: nil, reminder: ReminderSettings()))
        XCTAssertTrue(store.setProgressEnabled(true))
        let first = store.tasks[0]
        let second = store.tasks[1]
        _ = store.activeSections
        _ = store.activeTasks(in: nil, progressMarkerID: todo.id)
        XCTAssertTrue(store.setProgress(taskID: first.id, markerID: doing.id))
        XCTAssertEqual(store.activeSections.first?.tasks.map(\.id), [second.id, first.id])
        XCTAssertEqual(store.activeTasks(in: nil, progressMarkerID: todo.id).map(\.id), [second.id])
        XCTAssertEqual(store.activeTasks(in: nil, progressMarkerID: doing.id).map(\.id), [first.id])
        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertEqual(store.tasks[0].reminder, first.reminder)
        XCTAssertEqual(TaskStore(storageURL: url, notifications: nil).tasks[0].progressMarkerID, doing.id)
    }

    func testDisablingRetainsAssignmentsAndRestoresManualOrder() {
        let first = TaskItem(title: "First", progressMarkerID: doing.id)
        let second = TaskItem(title: "Second", progressMarkerID: todo.id)
        let store = enabledStore([first, second])
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [second.id, first.id])
        XCTAssertTrue(store.setProgressEnabled(false))
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [first.id, second.id])
        XCTAssertEqual(store.tasks[0].progressMarkerID, doing.id)
        XCTAssertFalse(store.setProgress(taskID: first.id, markerID: todo.id))
        XCTAssertTrue(store.setProgressEnabled(true))
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [second.id, first.id])
    }

    func testRenamingAndReorderingLabelsKeepExistingAssignments() {
        let first = TaskItem(title: "Legacy unassigned")
        let second = TaskItem(title: "Doing", progressMarkerID: doing.id)
        let store = enabledStore([first, second])
        _ = store.activeSections
        _ = store.progressMarker(for: first)
        var renamed = doing
        renamed.label = "Working"
        let config = ProgressConfiguration(isEnabled: true, markers: [renamed, todo])
        XCTAssertTrue(store.updateProgressConfiguration(config))
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [second.id, first.id])
        XCTAssertEqual(store.tasks[0].progressMarkerID, todo.id)
        XCTAssertEqual(store.progressMarker(for: store.tasks[1]).label, "Working")
        XCTAssertTrue(store.add(title: "New task", description: "", groupID: nil, reminder: ReminderSettings()))
        XCTAssertEqual(store.tasks.first(where: { $0.title == "New task" })?.progressMarkerID, doing.id)
    }

    func testBothDefaultsCanBeRemovedAndUsedLabelsMapToFirstRemainingOnSave() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let archived = TaskItem(title: "Archived", isCompleted: true, archivedAt: Date(timeIntervalSince1970: 100), progressMarkerID: doing.id)
        let original = PlanningData(tasks: [TaskItem(title: "Todo"), archived], groups: [])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(original).write(to: url)
        let store = TaskStore(storageURL: url, notifications: nil)
        let custom = ProgressMarker(label: "Draft")
        let config = ProgressConfiguration(isEnabled: true, markers: [custom])
        XCTAssertTrue(store.updateProgressConfiguration(config))
        XCTAssertEqual(store.tasks.map(\.progressMarkerID), [custom.id, custom.id])
        XCTAssertTrue(store.tasks[1].isArchived)
        XCTAssertEqual(TaskStore(storageURL: url, notifications: nil).progressConfiguration, config)
        XCTAssertEqual(TaskStore(storageURL: url, notifications: nil).tasks, store.tasks)
    }

    func testInvalidConfigurationsAndUnknownSelectionDoNotWrite() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var writes = 0
        let store = TaskStore(storageURL: url, notifications: nil, write: { data, url in
            writes += 1
            try data.write(to: url, options: .atomic)
        })
        XCTAssertTrue(store.add(title: "Task", description: "", groupID: nil, reminder: ReminderSettings()))
        XCTAssertTrue(store.setProgressEnabled(true))
        let before = writes
        for markers in [[], [todo, todo], [todo, ProgressMarker(label: "to DO")], [ProgressMarker(label: " ")]] {
            XCTAssertFalse(store.updateProgressConfiguration(ProgressConfiguration(isEnabled: true, markers: markers)))
        }
        XCTAssertFalse(store.setProgress(taskID: store.tasks[0].id, markerID: UUID()))
        XCTAssertEqual(writes, before)
        XCTAssertEqual(store.progressConfiguration.markers, [todo, doing])
    }

    func testFailedConfigurationAndProgressWritesRetainStateAndBytes() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var fail = false
        let store = TaskStore(storageURL: url, notifications: nil, write: { data, url in
            if fail { throw CocoaError(.fileWriteNoPermission) }
            try data.write(to: url, options: .atomic)
        })
        XCTAssertTrue(store.add(title: "Task", description: "", groupID: nil, reminder: ReminderSettings()))
        let original = store.tasks
        let bytes = try Data(contentsOf: url)
        fail = true
        XCTAssertFalse(store.setProgressEnabled(true))
        XCTAssertFalse(store.progressConfiguration.isEnabled)
        XCTAssertEqual(store.tasks, original)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        fail = false
        XCTAssertTrue(store.setProgressEnabled(true))
        let saved = store.tasks
        let enabledBytes = try Data(contentsOf: url)
        fail = true
        XCTAssertFalse(store.setProgress(taskID: saved[0].id, markerID: doing.id))
        XCTAssertEqual(store.tasks, saved)
        XCTAssertEqual(try Data(contentsOf: url), enabledBytes)
    }

    func testDraggingAcrossProgressChangesLabelButNeverCrossesGroups() {
        let first = TaskItem(title: "First", progressMarkerID: todo.id)
        let doingTask = TaskItem(title: "Doing", progressMarkerID: doing.id)
        let second = TaskItem(title: "Second", progressMarkerID: todo.id)
        let group = TaskGroup(name: "Other")
        let other = TaskItem(title: "Other group", groupID: group.id, progressMarkerID: todo.id)
        let store = enabledStore([first, doingTask, second, other], groups: [group])
        XCTAssertFalse(store.move(taskID: first.id, before: other.id))
        XCTAssertTrue(store.move(taskID: first.id, before: doingTask.id))
        XCTAssertEqual(store.tasks.first(where: { $0.id == first.id })?.progressMarkerID, doing.id)
        XCTAssertTrue(store.moveToEnd(taskID: first.id))
        XCTAssertEqual(store.activeTasks(in: nil).map(\.id), [second.id, doingTask.id, first.id])
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [other.id])
        XCTAssertTrue(store.tasks.allSatisfy { !$0.isCompleted })
    }

    func testDroppingIntoAnEmptyProgressSectionAssignsItAndRetainsGroup() {
        let group = TaskGroup(name: "Work")
        let task = TaskItem(title: "Plan", groupID: group.id, progressMarkerID: todo.id)
        let store = enabledStore([task], groups: [group])
        XCTAssertTrue(store.activeSections[0].progressSections[1].tasks.isEmpty)
        XCTAssertTrue(store.move(taskID: task.id, toProgressMarker: doing.id))
        XCTAssertEqual(store.tasks[0].groupID, group.id)
        XCTAssertEqual(store.tasks[0].progressMarkerID, doing.id)
        XCTAssertEqual(store.activeSections[0].progressSections[1].tasks.map(\.id), [task.id])
        XCTAssertFalse(store.tasks[0].isCompleted)
    }

    func testFailedReorderRollsBackWarmProgressLanesAndKeepsConfiguration() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = TaskItem(title: "First", progressMarkerID: todo.id)
        let second = TaskItem(title: "Second", progressMarkerID: todo.id)
        let snapshot = PlanningData(tasks: [first, second], groups: [], progressConfiguration: ProgressConfiguration(isEnabled: true))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url)
        let store = TaskStore(storageURL: url, notifications: nil, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        XCTAssertTrue(store.move(taskID: first.id, toProgressMarker: doing.id, persist: false))
        _ = store.activeTasks(in: nil, progressMarkerID: todo.id)
        XCTAssertFalse(store.persistTaskOrder())
        XCTAssertEqual(store.activeTasks(in: nil, progressMarkerID: todo.id).map(\.id), [first.id, second.id])
        XCTAssertEqual(store.progressConfiguration, snapshot.progressConfiguration)
    }

    func testCompletionArchiveRestoreKeepProgressAndCopyStartsFresh() throws {
        let original = TaskItem(title: "Original", progressMarkerID: doing.id)
        let store = enabledStore([original])
        XCTAssertTrue(store.toggleCompletion(for: original.id))
        XCTAssertTrue(store.archive(taskID: original.id))
        XCTAssertTrue(store.restore(taskID: original.id))
        XCTAssertEqual(store.completedTasks[0].progressMarkerID, doing.id)
        let draft = store.completedTasks[0].newTaskDraft(in: [])
        XCTAssertNil(draft.progressMarkerID)
        XCTAssertFalse(draft.isCompleted)
        XCTAssertTrue(store.toggleCompletion(for: original.id))
        XCTAssertEqual(store.progressMarker(for: store.incompleteTasks[0]), doing)
        XCTAssertFalse(store.setProgress(taskID: UUID(), markerID: todo.id))
    }

    func testCorruptProgressSnapshotsAreProtected() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        for markers in [[], [todo, todo]] {
            let snapshot = PlanningData(tasks: [], groups: [], progressConfiguration: ProgressConfiguration(isEnabled: true, markers: markers))
            let bytes = try JSONEncoder().encode(snapshot)
            try bytes.write(to: url)
            let store = TaskStore(storageURL: url, notifications: nil)
            XCTAssertTrue(store.hasLoadFailure)
            XCTAssertFalse(store.setProgressEnabled(true))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }

    func testProgressBarReservesFilledStateForCompletionAndRefreshesOnLabelOrder() {
        let task = TaskItem(title: "Working", progressMarkerID: doing.id)
        let store = enabledStore([task])
        XCTAssertEqual(store.progressFraction(for: task), 0.5)
        let reversed = ProgressConfiguration(isEnabled: true, markers: [doing, todo])
        XCTAssertTrue(store.updateProgressConfiguration(reversed))
        XCTAssertEqual(store.progressFraction(for: task), 0)
        var completed = task
        completed.isCompleted = true
        XCTAssertEqual(store.progressFraction(for: completed), 1)
        store.releasePresentationCaches()
        XCTAssertEqual(store.progressFraction(for: task), 0)
    }

    func testCachePurgeDoesNotPublishOrChangeAssignments() {
        let task = TaskItem(title: "Doing", progressMarkerID: doing.id)
        let store = enabledStore([task])
        _ = store.activeSections
        _ = store.activeTasks(in: nil, progressMarkerID: doing.id)
        _ = store.progressMarker(for: task)
        var events = 0
        let subscription = store.objectWillChange.sink { events += 1 }
        let revision = store.taskRevision
        store.releasePresentationCaches()
        XCTAssertEqual(events, 0)
        XCTAssertEqual(store.taskRevision, revision)
        XCTAssertEqual(store.activeTasks(in: nil, progressMarkerID: doing.id).map(\.id), [task.id])
        XCTAssertEqual(store.progressMarker(for: task), doing)
        withExtendedLifetime(subscription) {}
    }

    func testProgressChangeDoesNotInvalidatePendingReminderScheduling() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let scheduler = ProgressReminderSpy()
        let store = TaskStore(storageURL: url, notifications: scheduler)
        XCTAssertTrue(store.setProgressEnabled(true))
        var reminder = ReminderSettings()
        reminder.isEnabled = true
        XCTAssertTrue(store.add(title: "Reminder", description: "", groupID: nil, reminder: reminder))
        let id = store.tasks[0].id
        // Change metadata before the queued reminder operation begins.
        XCTAssertTrue(store.setProgress(taskID: id, markerID: doing.id))
        for _ in 0..<20 where scheduler.scheduled.isEmpty { await Task.yield() }
        XCTAssertEqual(scheduler.scheduled, [id])
        XCTAssertTrue(scheduler.cancelled.isEmpty)
    }
}

@MainActor
private final class ProgressReminderSpy: TaskNotificationScheduling {
    var scheduled: [UUID] = []
    var cancelled: [UUID] = []
    func schedule(for task: TaskItem) async { scheduled.append(task.id) }
    func cancel(for taskID: UUID) { cancelled.append(taskID) }
}
