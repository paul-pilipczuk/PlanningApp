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

    func testGroupedListsKeepOrderAcrossCompletionAndReordering() {
        let group = TaskGroup(name: "Work")
        let empty = TaskGroup(name: "Empty")
        let first = TaskItem(title: "First", groupID: group.id)
        let second = TaskItem(title: "Second", groupID: group.id)
        let general = TaskItem(title: "General task")
        let completed = TaskItem(title: "Finished", groupID: group.id, isCompleted: true)
        let store = TaskStore(sampleData: PlanningData(tasks: [second, completed, general, first], groups: [group, empty]))

        XCTAssertEqual(store.activeSections.map(\.title), ["Work", "Empty", "General"])
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [second.id, first.id])
        XCTAssertTrue(store.activeSections[1].tasks.isEmpty)
        XCTAssertEqual(store.activeSections[2].tasks.map(\.id), [general.id])
        XCTAssertTrue(store.move(taskID: first.id, before: second.id, persist: false))
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [first.id, second.id])
        store.toggleCompletion(for: first.id)
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [second.id])
        store.toggleCompletion(for: first.id)
        XCTAssertEqual(store.activeSections[0].tasks.map(\.id), [first.id, second.id])
    }

    func testGroupedListConstructionPerformance() {
        let groups = (0..<100).map { TaskGroup(name: "Group \($0)") }
        let reminder = ReminderSettings(hour: 9, minute: 0, weekday: 2)
        let tasks = (0..<10_000).map { index in
            TaskItem(title: "Task \(index)",
                     groupID: index.isMultiple(of: 10) ? nil : groups[index % groups.count].id,
                     isCompleted: index.isMultiple(of: 4), reminder: reminder)
        }
        let store = TaskStore(sampleData: PlanningData(tasks: tasks, groups: groups))
        measure {
            for _ in 0..<5 {
                XCTAssertEqual(store.activeSections.reduce(0) { $0 + $1.tasks.count }, 7_500)
            }
        }
    }

    func testRepeatedTaskCollectionReadsPerformance() {
        let data = performanceData()
        let store = TaskStore(sampleData: data)
        XCTAssertEqual(readListCounts(store), 16_000)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<50 {
                XCTAssertEqual(readListCounts(store), 16_000)
            }
        }
    }

    func testColdTaskCollectionsPerformance() {
        let data = performanceData()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<5 {
                let store = TaskStore(sampleData: data)
                XCTAssertEqual(readListCounts(store), 16_000)
            }
        }
    }

    private func readListCounts(_ store: TaskStore) -> Int {
        store.incompleteTasks.count + store.completedTasks.count + store.archivedTasks.count
            + store.activeSections.reduce(0) { $0 + $1.tasks.count }
    }

    private func performanceData() -> PlanningData {
        let groups = (0..<100).map { TaskGroup(name: "Group \($0)") }
        let reminder = ReminderSettings(hour: 9, minute: 0, weekday: 2)
        let tasks = (0..<10_000).map { index in
            TaskItem(title: "Task \(index)", description: "Fixed benchmark details",
                     groupID: index.isMultiple(of: 11) ? nil : groups[index % groups.count].id,
                     isCompleted: index % 5 < 2, reminder: reminder,
                     archivedAt: index % 5 == 1 ? Date(timeIntervalSince1970: Double(index % 97)) : nil)
        }
        return PlanningData(tasks: tasks, groups: groups)
    }

}
