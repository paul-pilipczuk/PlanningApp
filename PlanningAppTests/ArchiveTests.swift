import XCTest
@testable import PlanningApp

@MainActor
final class ArchiveTests: XCTestCase {
    func testArchiveAndRestorePreserveFieldsAndOriginalOrderAcrossRelaunch() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let notifications = ReminderSpy()
        let store = TaskStore(storageURL: url, notifications: notifications, now: { date })
        let group = try XCTUnwrap(store.createGroup(named: "Work"))
        XCTAssertTrue(store.add(title: "Keep this", description: "Full details", groupID: group.id, reminder: ReminderSettings()))
        let id = try XCTUnwrap(store.tasks.first?.id)
        XCTAssertTrue(store.toggleCompletion(for: id))
        let original = try XCTUnwrap(store.tasks.first)
        XCTAssertTrue(store.archive(taskID: id))
        XCTAssertTrue(store.completedTasks.isEmpty)
        XCTAssertTrue(store.incompleteTasks.isEmpty)
        XCTAssertEqual(store.archivedTasks.first?.archivedAt, date)
        XCTAssertEqual(store.archivedTasks.first?.description, original.description)
        XCTAssertTrue(notifications.cancelled.contains(id))
        let reopened = TaskStore(storageURL: url, notifications: nil)
        XCTAssertEqual(reopened.archivedTasks.map(\.id), [id])
        XCTAssertTrue(reopened.restore(taskID: id))
        XCTAssertEqual(reopened.completedTasks, [original])
        XCTAssertTrue(reopened.archivedTasks.isEmpty)
    }

    func testArchivedTasksRejectStaleEditsCompletionAndReorder() {
        let archived = TaskItem(title: "Saved", isCompleted: true, archivedAt: Date(timeIntervalSince1970: 100))
        let active = TaskItem(title: "Active")
        let store = TaskStore(sampleData: PlanningData(tasks: [archived, active], groups: []))
        XCTAssertFalse(store.toggleCompletion(for: archived.id))
        XCTAssertFalse(store.update(taskID: archived.id, title: "Changed", description: "", groupID: nil, reminder: ReminderSettings()))
        XCTAssertFalse(store.move(taskID: archived.id, before: active.id))
        XCTAssertFalse(store.move(taskID: active.id, before: archived.id))
        XCTAssertFalse(store.moveToEnd(taskID: archived.id))
        XCTAssertFalse(store.archive(taskID: active.id))
        XCTAssertEqual(store.tasks, [archived, active])
    }

    func testArchiveSortsNewestFirstAndRestoresWithoutScheduling() {
        let oldest = TaskItem(title: "Old", isCompleted: true, archivedAt: Date(timeIntervalSince1970: 1))
        let newest = TaskItem(title: "New", isCompleted: true, archivedAt: Date(timeIntervalSince1970: 2))
        let store = TaskStore(sampleData: PlanningData(tasks: [oldest, newest], groups: []))
        XCTAssertEqual(store.archivedTasks.map(\.id), [newest.id, oldest.id])
        XCTAssertTrue(store.restore(taskID: oldest.id))
        XCTAssertEqual(store.completedTasks.map(\.id), [oldest.id])
    }

    func testFailedArchiveRestoreAndDeletionPreserveSavedDataAndNotifications() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let completed = TaskItem(title: "Keep", isCompleted: true)
        let archived = TaskItem(title: "Archived", isCompleted: true, archivedAt: Date(timeIntervalSince1970: 100))
        let original = try JSONEncoder().encode(PlanningData(tasks: [completed, archived], groups: []))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try original.write(to: url)
        let notifications = ReminderSpy()
        let store = TaskStore(storageURL: url, notifications: notifications, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        XCTAssertFalse(store.update(taskID: completed.id, title: "Changed", description: "", groupID: nil, reminder: ReminderSettings()))
        XCTAssertFalse(store.toggleCompletion(for: completed.id))
        XCTAssertNil(store.createGroup(named: "Not saved"))
        XCTAssertFalse(store.archive(taskID: completed.id))
        XCTAssertFalse(store.restore(taskID: archived.id))
        XCTAssertFalse(store.delete(taskID: completed.id))
        XCTAssertEqual(store.tasks, [completed, archived])
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertTrue(notifications.cancelled.isEmpty)
        XCTAssertNotNil(store.errorMessage)
    }

    func testUnreadableAndFutureDataCannotBeOverwrittenAndCanRetry() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        for bytes in [Data("broken data".utf8), Data("{\"version\":99,\"tasks\":[],\"groups\":[]}".utf8)] {
            try bytes.write(to: url)
            let store = TaskStore(storageURL: url, notifications: nil)
            XCTAssertTrue(store.hasLoadFailure)
            XCTAssertFalse(store.add(title: "Do not overwrite", description: "", groupID: nil, reminder: ReminderSettings()))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            let valid = PlanningData(tasks: [TaskItem(title: "Recovered")], groups: [])
            try JSONEncoder().encode(valid).write(to: url)
            store.reload()
            XCTAssertFalse(store.hasLoadFailure)
            XCTAssertEqual(store.tasks, valid.tasks)
        }
    }

    func testVersionTwoAndLegacyArraysLoadWithoutInventingArchives() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let task = TaskItem(title: "Existing", description: "Details", isCompleted: true)
        var old = PlanningData(tasks: [task], groups: [])
        old.version = 2
        for bytes in [try JSONEncoder().encode(old), try JSONEncoder().encode([task])] {
            try bytes.write(to: url)
            let store = TaskStore(storageURL: url, notifications: nil)
            XCTAssertFalse(store.hasLoadFailure)
            XCTAssertEqual(store.completedTasks, [task])
            XCTAssertTrue(store.archivedTasks.isEmpty)
            XCTAssertTrue(store.archive(taskID: task.id))
            let saved = try JSONDecoder().decode(PlanningData.self, from: Data(contentsOf: url))
            XCTAssertEqual(saved.version, 3)
        }
    }

    func testMissingGroupFallsBackToGeneralAndFailedReorderRollsBack() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = TaskItem(title: "First", groupID: UUID())
        let second = TaskItem(title: "Second", groupID: first.groupID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(PlanningData(tasks: [first, second], groups: [])).write(to: url)
        let store = TaskStore(storageURL: url, notifications: nil, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        XCTAssertEqual(store.activeSections.first?.title, "General")
        XCTAssertEqual(store.activeSections.first?.tasks.count, 2)
        XCTAssertTrue(store.move(taskID: second.id, before: first.id, persist: false))
        XCTAssertFalse(store.persistTaskOrder())
        XCTAssertEqual(store.tasks.map(\.id), [first.id, second.id])
    }

    func testRestoreKeepsReminderConfigurationWithoutSchedulingAndDeletePersists() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var reminder = ReminderSettings(hour: 9, minute: 0, weekday: 2)
        reminder.isEnabled = true
        let task = TaskItem(title: "Saved reminder", isCompleted: true, reminder: reminder, archivedAt: Date(timeIntervalSince1970: 1))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(PlanningData(tasks: [task], groups: [])).write(to: url)
        let notifications = ReminderSpy()
        let store = TaskStore(storageURL: url, notifications: notifications)
        XCTAssertTrue(store.restore(taskID: task.id))
        XCTAssertEqual(store.completedTasks.first?.reminder, reminder)
        XCTAssertTrue(notifications.scheduled.isEmpty)
        XCTAssertEqual(notifications.cancelled, [task.id])
        XCTAssertTrue(store.archive(taskID: task.id))
        XCTAssertTrue(store.delete(taskID: task.id))
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(TaskStore(storageURL: url, notifications: nil).tasks.isEmpty)
    }

    func testInconsistentArchiveAndDuplicateIDsAreRejectedWithoutOverwrite() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let invalid = TaskItem(title: "Invalid", archivedAt: Date(timeIntervalSince1970: 1))
        let task = TaskItem(title: "Duplicate")
        for snapshot in [PlanningData(tasks: [invalid], groups: []), PlanningData(tasks: [task, task], groups: [])] {
            let bytes = try JSONEncoder().encode(snapshot)
            try bytes.write(to: url)
            let store = TaskStore(storageURL: url, notifications: nil)
            XCTAssertTrue(store.hasLoadFailure)
            XCTAssertFalse(store.add(title: "New", description: "", groupID: nil, reminder: ReminderSettings()))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }

    func testCopyDraftCreatesDistinctActiveTaskAndPreservesArchiveAcrossRelaunch() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let group = TaskGroup(name: "Work")
        var reminder = ReminderSettings(hour: 9, minute: 30, weekday: 2)
        reminder.isEnabled = true
        let original = TaskItem(title: "Reusable plan", description: "Full instructions", groupID: group.id,
                                isCompleted: true, reminder: reminder, archivedAt: Date(timeIntervalSince1970: 100))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(PlanningData(tasks: [original], groups: [group])).write(to: url)
        let store = TaskStore(storageURL: url, notifications: nil)
        let draft = original.newTaskDraft(in: store.groups)
        XCTAssertNotEqual(draft.id, original.id)
        XCTAssertFalse(draft.isCompleted)
        XCTAssertFalse(draft.isArchived)
        XCTAssertEqual(draft.reminder, reminder)
        XCTAssertEqual(store.tasks, [original], "Preparing or discarding a copy never mutates storage")
        XCTAssertTrue(store.add(title: draft.title, description: draft.description, groupID: draft.groupID, reminder: draft.reminder))
        let reopened = TaskStore(storageURL: url, notifications: nil)
        let copy = try XCTUnwrap(reopened.incompleteTasks.first)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.title, original.title)
        XCTAssertEqual(copy.description, original.description)
        XCTAssertEqual(copy.groupID, group.id)
        XCTAssertEqual(copy.reminder, original.reminder)
        XCTAssertEqual(reopened.archivedTasks, [original])
    }

    func testCopyOfTaskWithMissingGroupStartsInGeneral() {
        let original = TaskItem(title: "Legacy archive", groupID: UUID(), isCompleted: true, archivedAt: Date())
        let draft = original.newTaskDraft(in: [TaskGroup(name: "Different group")])
        XCTAssertNil(draft.groupID)
        XCTAssertNotNil(original.groupID)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("tasks.json")
    }
}

@MainActor
private final class ReminderSpy: TaskNotificationScheduling {
    var cancelled: [UUID] = []
    var scheduled: [TaskItem] = []
    func cancel(for id: UUID) { cancelled.append(id) }
    func schedule(for task: TaskItem) async { scheduled.append(task) }
}
