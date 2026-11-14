import XCTest

final class NavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-sample-data", "-ui-testing", "-reset-test-preferences"]
        app.launch()
        app.launchArguments.removeAll { $0 == "-reset-test-preferences" }
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
        XCTAssertTrue(app.buttons["Archived task: Archive sample plan 1"].exists)
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
        app.buttons["tab.settings"].tap()
        app.buttons["appearance.dark"].tap()
        app.buttons["tab.active"].tap()
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
        collapsed.name = "Compact Active header and soft scroll edge"
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
        XCTAssertEqual(app.staticTexts["page.title"].frame.midX, app.frame.midX, accuracy: 2)
        let completed = XCTAttachment(screenshot: app.screenshot())
        completed.name = "Compact Completed header and soft scroll edge"
        completed.lifetime = .keepAlways
        add(completed)
        let completedList = app.scrollViews["taskList.completed"]
        completedList.swipeDown(velocity: .fast)
        completedList.swipeDown(velocity: .fast)
        XCTAssertEqual(app.staticTexts["page.title"].frame.height, completedTitleHeight, accuracy: 2)
        XCTAssertTrue(expand.exists)
    }

    func testSettingsAndArchiveCollapseWhenContentOverflows() {
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
        XCTAssertEqual(app.staticTexts["page.title"].frame.midX, app.frame.midX, accuracy: 2)
        let settingsHeader = XCTAttachment(screenshot: app.screenshot())
        settingsHeader.name = "Compact Settings header and soft scroll edge"
        settingsHeader.lifetime = .keepAlways
        add(settingsHeader)
        expand.tap()
        app.buttons["tab.archived"].tap()
        XCTAssertTrue(app.scrollViews["archived.scroll"].exists)
        let archivedHeight = app.staticTexts["page.title"].frame.height
        app.scrollViews["archived.scroll"].swipeUp()
        XCTAssertTrue(expand.waitForExistence(timeout: 3))
        XCTAssertLessThan(app.staticTexts["page.title"].frame.height, archivedHeight)
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

    private func assertDisappears(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed, file: file, line: line)
    }

    private func requestCompletedRemoval() {
        app.buttons["tab.completed"].tap()
        app.buttons["Details for Set up the planning app"].tap()
        app.buttons["Remove Task…"].tap()
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 3))
    }

    func testArchiveAndRestoreFromCompletedTaskDetails() {
        requestCompletedRemoval()
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.staticTexts["page.title"].tap() }
        XCTAssertTrue(app.buttons["Mark Set up the planning app active"].exists)
        requestCompletedRemoval()
        app.buttons["Archive"].tap()
        assertDisappears(app.buttons["Mark Set up the planning app active"])
        app.buttons["tab.archived"].tap()
        let archived = app.buttons["Archived task: Set up the planning app"]
        XCTAssertTrue(archived.waitForExistence(timeout: 3))
        archived.tap()
        XCTAssertTrue(app.navigationBars["Archived Task"].waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Archived task details"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Restore to Completed"].tap()
        assertDisappears(archived)
        app.buttons["tab.completed"].tap()
        XCTAssertTrue(app.buttons["Mark Set up the planning app active"].waitForExistence(timeout: 3))
    }

    func testPermanentDeletionRequiresConfirmationAndCanBeCancelled() {
        for appearance in ["dark", "light"] {
            app.buttons["tab.settings"].tap()
            app.buttons["appearance.\(appearance)"].tap()
            requestCompletedRemoval()
            app.buttons["Delete Permanently…"].tap()
            let alert = app.alerts["Delete Task Permanently?"]
            XCTAssertTrue(alert.waitForExistence(timeout: 3))
            XCTAssertTrue(alert.buttons["Cancel"].isHittable)
            // Allow the system material's presentation transition to finish for visual review.
            Thread.sleep(forTimeInterval: 0.6)
            let confirmation = XCTAttachment(screenshot: app.screenshot())
            confirmation.name = "Settled native deletion confirmation — \(appearance)"
            confirmation.lifetime = .keepAlways
            add(confirmation)
            alert.buttons["Cancel"].tap()
            XCTAssertTrue(app.buttons["Mark Set up the planning app active"].exists)
        }
        requestCompletedRemoval()
        app.buttons["Delete Permanently…"].tap()
        XCTAssertTrue(app.alerts["Delete Task Permanently?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Delete Permanently"].tap()
        assertDisappears(app.buttons["Mark Set up the planning app active"])
        app.buttons["tab.archived"].tap()
        XCTAssertFalse(app.buttons["Archived task: Set up the planning app"].exists)
    }

    func testArchivedTaskDeletionCanBeCancelledBeforeFinalConfirmation() {
        app.buttons["tab.archived"].tap()
        let task = app.buttons["Archived task: Archive sample plan 1"]
        XCTAssertTrue(task.waitForExistence(timeout: 3))
        task.tap()
        app.buttons["Delete Permanently…"].tap()
        XCTAssertTrue(app.alerts["Delete Task Permanently?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Archived Task"].exists)
        app.buttons["Delete Permanently…"].tap()
        XCTAssertTrue(app.alerts["Delete Task Permanently?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Delete Permanently"].tap()
        assertDisappears(app.navigationBars["Archived Task"])
        assertDisappears(task)
    }

    func testNavigationPreferencePersistsAndKeepsBarExpandedWhileHeadingCompacts() {
        app.buttons["tab.settings"].tap()
        let toggle = app.switches["settings.keepNavigationExpanded"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        app.terminate()
        app.launch()
        app.buttons["tab.completed"].tap()
        let initialHeight = app.staticTexts["page.title"].frame.height
        app.scrollViews["taskList.completed"].swipeUp()
        XCTAssertTrue(app.buttons["tab.settings"].exists)
        XCTAssertFalse(app.buttons["navigation.expand"].exists)
        XCTAssertLessThan(app.staticTexts["page.title"].frame.height, initialHeight)
        app.buttons["tab.settings"].tap()
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
    }

    func testTaskDetailsAndCreationRemainAvailable() {
        app.buttons["Details for Plan the week"].tap()
        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        app.buttons["Add task"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
    }
}
