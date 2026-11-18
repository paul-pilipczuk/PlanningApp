import XCTest
import UserNotifications
@testable import PlanningApp

@MainActor
final class ReminderTests: XCTestCase {
    func testWeeklyTriggerUsesSelectedWeekdayHourAndMinute() {
        var settings = ReminderSettings(hour: 9, minute: 45, weekday: 6)
        settings.isEnabled = true
        settings.frequency = .weekly
        let trigger = NotificationManager.shared.makeTrigger(from: settings)
        XCTAssertEqual(trigger.dateComponents.weekday, 6)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 45)
        XCTAssertTrue(trigger.repeats)
    }

    func testDailyTriggerDoesNotRestrictWeekday() {
        var settings = ReminderSettings(hour: 16, minute: 20, weekday: 6)
        settings.isEnabled = true
        settings.frequency = .daily
        let trigger = NotificationManager.shared.makeTrigger(from: settings)
        XCTAssertNil(trigger.dateComponents.weekday)
        XCTAssertEqual(trigger.dateComponents.hour, 16)
        XCTAssertEqual(trigger.dateComponents.minute, 20)
    }

    func testWeeklyScheduleSurvivesSaveAndReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("tasks.json")
        let store = TaskStore(storageURL: url, notifications: nil)
        var settings = ReminderSettings(hour: 18, minute: 35, weekday: 3)
        settings.isEnabled = true
        settings.frequency = .weekly
        XCTAssertTrue(store.add(title: "Weekly task", description: "", groupID: nil, reminder: settings))
        let reopened = TaskStore(storageURL: url, notifications: nil)
        XCTAssertEqual(reopened.incompleteTasks.first?.reminder, settings)
    }
}
