import XCTest
@testable import PlanningApp

@MainActor
final class SampleTaskDataTests: XCTestCase {
    func testFixtureHasEnoughActiveAndCompletedTasksToScroll() throws {
        let data = try SampleTaskData.load()

        XCTAssertGreaterThanOrEqual(data.tasks.filter { !$0.isCompleted }.count, 20)
        XCTAssertGreaterThanOrEqual(data.tasks.filter(\.isCompleted).count, 20)
        XCTAssertEqual(Set(data.tasks.map(\.id)).count, data.tasks.count)
        XCTAssertTrue(data.tasks.allSatisfy { !$0.title.isEmpty && !$0.reminder.isEnabled })
        let groupIDs = Set(data.groups.map(\.id))
        XCTAssertTrue(data.tasks.allSatisfy { $0.groupID.map(groupIDs.contains) ?? true })
    }

    func testSampleEditsAreDiscardedWhenStartingANewSession() throws {
        let data = try SampleTaskData.load()
        let originalTask = try XCTUnwrap(data.tasks.first)
        let store = TaskStore(sampleData: data)

        store.toggleCompletion(for: originalTask.id)
        store.delete(taskID: originalTask.id)
        store.add(title: "Temporary sample task", description: "", groupID: nil, reminder: ReminderSettings())

        let freshSession = TaskStore(sampleData: data)
        XCTAssertEqual(freshSession.tasks, data.tasks)
        XCTAssertEqual(freshSession.groups, data.groups)
    }

    func testSampleEditsLeaveExistingSavedTasksUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("tasks.json")
        let saved = PlanningData(tasks: [TaskItem(title: "My existing task")], groups: [])
        let originalBytes = try JSONEncoder().encode(saved)
        try originalBytes.write(to: url)
        let existing = TaskStore(storageURL: url, notifications: nil)
        let samples = TaskStore(sampleData: try SampleTaskData.load())

        samples.delete(taskID: try XCTUnwrap(samples.tasks.first).id)
        _ = samples.createGroup(named: "Temporary group")
        samples.persistTaskOrder()

        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        XCTAssertEqual(existing.tasks, saved.tasks)
    }

    func testInjectedStorageKeepsCompletionAcrossRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("tasks.json")
        let store = TaskStore(storageURL: url, notifications: nil)
        store.add(title: "Persistent task", description: "Details", groupID: nil, reminder: ReminderSettings())
        let task = try XCTUnwrap(store.tasks.first)
        store.toggleCompletion(for: task.id)

        let reopened = TaskStore(storageURL: url, notifications: nil)
        XCTAssertEqual(reopened.completedTasks.map(\.id), [task.id])
        XCTAssertEqual(reopened.tasks.first?.description, "Details")
    }
}
