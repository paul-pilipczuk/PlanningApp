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
        for tab in ["settings", "active", "archived", "completed", "settings", "archived", "active"] {
            let button = app.buttons["tab.\(tab)"]
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertEqual(app.staticTexts["page.title"].label.lowercased(), tab)
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
        scrollThroughGutter(list)
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
        app.scrollViews["taskList.completed"].swipeUp()
        XCTAssertTrue(expand.waitForExistence(timeout: 3))
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

    func testTaskDetailsAndCreationRemainAvailable() {
        app.buttons["Details for Plan the week"].tap()
        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        app.buttons["Add task"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
    }
}
