import XCTest

final class NavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-sample-data"]
        app.launch()
    }

    private func scrollThroughGutter(_ list: XCUIElement) {
        // Preserve the existing row-drag interaction; scroll using the list margin.
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.8))
        let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func testFourDestinationsAndAppearance() {
        XCTAssertTrue(app.buttons["tab.active"].waitForExistence(timeout: 5))
        app.buttons["tab.completed"].tap()
        XCTAssertTrue(app.staticTexts["page.title"].label == "Completed")
        app.buttons["tab.archived"].tap()
        XCTAssertTrue(app.staticTexts["Coming soon"].exists)
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["page.title"].label == "Settings")
        app.buttons["appearance.light"].tap()
        XCTAssertTrue(app.buttons["appearance.light"].isSelected)
        let light = XCTAttachment(screenshot: app.screenshot())
        light.name = "Light appearance"
        light.lifetime = .keepAlways
        add(light)
        app.terminate()
        app.launch()
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.buttons["appearance.light"].isSelected)
        app.buttons["tab.active"].tap()
        XCTAssertTrue(app.staticTexts["page.title"].label == "Active")
    }

    func testSkippingTabsKeepsSelectionAndHeaderInSync() {
        let navigation = app.otherElements["navigation.bar"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 3))
        let initialFrame = navigation.frame
        for tab in ["settings", "active", "archived", "completed", "settings", "archived", "active"] {
            let button = app.buttons["tab.\(tab)"]
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertEqual(app.staticTexts["page.title"].label.lowercased(), tab)
            XCTAssertEqual(navigation.frame.minX, initialFrame.minX, accuracy: 1)
            XCTAssertEqual(navigation.frame.minY, initialFrame.minY, accuracy: 1)
            XCTAssertEqual(navigation.frame.width, initialFrame.width, accuracy: 1)
            XCTAssertEqual(navigation.frame.height, initialFrame.height, accuracy: 1)
        }
        let title = app.staticTexts["page.title"]
        let add = app.buttons["task.add"]
        XCTAssertTrue(add.isHittable)
        XCTAssertLessThan(abs(title.frame.midY - add.frame.midY), 20)
        add.tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
    }

    func testScrollingCollapsesToLeadingCircleAndTapExpands() {
        let tab = app.buttons["tab.active"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        let list = app.scrollViews["taskList.active"]
        XCTAssertGreaterThan(list.frame.maxY, tab.frame.minY)
        let largeTitleHeight = app.staticTexts["page.title"].frame.height
        scrollThroughGutter(list)
        XCTAssertLessThan(app.staticTexts["page.title"].frame.height, largeTitleHeight)
        XCTAssertLessThan(abs(app.staticTexts["page.title"].frame.midY - app.buttons["task.add"].frame.midY), 20)
        let expand = app.buttons["navigation.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 3))
        XCTAssertLessThan(expand.frame.midX, app.frame.width / 3)
        XCTAssertGreaterThanOrEqual(expand.frame.width, 44)
        let collapsed = XCTAttachment(screenshot: app.screenshot())
        collapsed.name = "Collapsed navigation"
        collapsed.lifetime = .keepAlways
        add(collapsed)
        expand.tap()
        XCTAssertTrue(tab.waitForExistence(timeout: 3))
        app.buttons["tab.completed"].tap()
        XCTAssertTrue(app.buttons["tab.settings"].exists)
        let completedTitleHeight = app.staticTexts["page.title"].frame.height
        app.scrollViews["taskList.completed"].swipeUp()
        XCTAssertTrue(expand.waitForExistence(timeout: 3))
        XCTAssertLessThan(app.staticTexts["page.title"].frame.height, completedTitleHeight)
        let completedList = app.scrollViews["taskList.completed"]
        completedList.swipeDown(velocity: .fast)
        completedList.swipeDown(velocity: .fast)
        XCTAssertEqual(app.staticTexts["page.title"].frame.height, completedTitleHeight, accuracy: 2)
        XCTAssertTrue(expand.exists)
    }

    func testSettingsCollapseWhenContentOverflowsAndArchivedStaysExpanded() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["tab.settings"].tap()
        let largeTitleHeight = app.staticTexts["page.title"].frame.height
        let settings = app.scrollViews["settings.scroll"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.swipeUp()
        let expand = app.buttons["navigation.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 3))
        XCTAssertLessThan(app.staticTexts["page.title"].frame.height, largeTitleHeight)
        expand.tap()
        app.buttons["tab.archived"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["tab.settings"].exists)
        XCTAssertFalse(expand.exists)
    }

    func testTaskCompletionMovesBetweenTabs() {
        let title = "Plan the week"
        let task = app.buttons["Complete \(title)"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        app.buttons["tab.completed"].tap()
        let completed = app.buttons["Mark \(title) active"]
        XCTAssertTrue(completed.waitForExistence(timeout: 3))
        completed.tap()
        app.buttons["tab.active"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 3))
    }

    func testActiveTaskDragStillReordersWithoutCollapsingNavigation() {
        let first = app.buttons["Complete Plan the week"]
        let second = app.buttons["Complete Review the project notes"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertLessThan(first.frame.midY, second.frame.midY)
        let start = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.15, thenDragTo: end)
        XCTAssertGreaterThan(first.frame.midY, second.frame.midY)
        XCTAssertTrue(app.buttons["tab.active"].exists)
        XCTAssertFalse(app.buttons["navigation.expand"].exists)
    }

    func testTaskDetailsAndCreationRemainAvailable() {
        app.buttons["Details for Plan the week"].tap()
        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        app.buttons["Add task"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
    }
}
