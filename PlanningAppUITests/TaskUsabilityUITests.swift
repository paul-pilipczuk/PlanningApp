import XCTest

final class TaskUsabilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-sample-data", "-ui-testing", "-reset-test-preferences"]
        app.launch()
        app.launchArguments.removeAll { $0 == "-reset-test-preferences" }
    }

    private func assertDisappears(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed, file: file, line: line)
    }

    private func launchEmptyActive() {
        app.terminate()
        app.launchArguments += ["-short-completed-data"]
        app.launch()
        XCTAssertTrue(app.buttons["task.emptyActive"].waitForExistence(timeout: 3))
    }

    private func openNewTask(title: String) {
        app.buttons["task.add"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        let field = app.textFields["task.title"]
        field.tap()
        field.typeText(title)
        app.keyboards.buttons["Done"].tap()
        assertDisappears(app.keyboards.firstMatch)
    }

    private func dismissKeyboardByDraggingForm() {
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["keyboard.dismiss"].exists)
        let form = app.collectionViews.firstMatch
        // The collection's accessibility frame extends behind the keyboard.
        // Begin on visible form content, above its keyboard-dismiss footer.
        let visibleBottom = min(form.frame.maxY, app.buttons["keyboard.dismiss"].frame.minY)
        let startY = max(form.frame.minY + 30, visibleBottom - 60)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = form.frame.minX + 8 - app.frame.minX
        let start = origin.withOffset(CGVector(dx: x, dy: startY - app.frame.minY))
        // Stop within the keyboard so the gesture does not become a full-sheet dismissal.
        let endY = min(app.frame.height * 0.95, app.keyboards.firstMatch.frame.midY - app.frame.minY)
        let end = origin.withOffset(CGVector(dx: x, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        assertDisappears(app.keyboards.firstMatch)
        assertDisappears(app.buttons["keyboard.dismiss"])
    }

    func testTaskTextOpensDetailsAndOnlyCircleChangesCompletion() {
        let title = "Plan the week"
        app.buttons["Task details: \(title)"].tap()
        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Complete \(title)"].exists)
        app.buttons["Complete \(title)"].tap()
        app.buttons["tab.completed"].tap()
        XCTAssertTrue(app.buttons["Mark \(title) active"].waitForExistence(timeout: 3))
        app.buttons["Task details: \(title)"].tap()
        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Mark \(title) active"].exists)
        app.buttons["Mark \(title) active"].tap()
        app.buttons["tab.active"].tap()
        XCTAssertTrue(app.buttons["Complete \(title)"].waitForExistence(timeout: 3))
    }

    func testEmptyActiveCanvasAndHeaderOpenCreationWithoutCapturingTabs() {
        launchEmptyActive()
        let canvas = app.buttons["task.emptyActive"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Add a plan"].exists)
        XCTAssertEqual(canvas.images.count, 0)
        for position in [CGVector(dx: 0.05, dy: 0.05), CGVector(dx: 0.5, dy: 0.45), CGVector(dx: 0.95, dy: 0.8)] {
            canvas.coordinate(withNormalizedOffset: position).tap()
            XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
            app.buttons["Cancel"].tap()
            XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        }
        app.staticTexts["page.title"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        // Capture the settled Active header before exercising the tab crossfade.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Empty Active canvas without image or extra button"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["tab.completed"].tap()
        XCTAssertEqual(app.staticTexts["page.title"].label, "Completed")
        XCTAssertFalse(app.navigationBars["New Task"].exists)
        app.buttons["tab.active"].tap()
    }

    func testCompletingLastActiveTaskRestoresEmptyCanvasAndNavigation() {
        launchEmptyActive()
        let largeTitleHeight = app.staticTexts["page.title"].frame.height
        openNewTask(title: "Last active plan")
        app.buttons["task.save"].tap()
        let completion = app.buttons["Complete Last active plan"]
        XCTAssertTrue(completion.waitForExistence(timeout: 3))
        completion.tap()
        XCTAssertTrue(app.buttons["task.emptyActive"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["page.title"].frame.height, largeTitleHeight, accuracy: 2)
        XCTAssertTrue(app.buttons["tab.settings"].isHittable)
        app.buttons["task.emptyActive"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
    }

    func testTitleDoneAndKeyboardControlDismissWithoutSaving() {
        launchEmptyActive()
        openNewTask(title: "Keyboard usability")
        XCTAssertTrue(app.navigationBars["New Task"].exists)
        app.textFields["task.title"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons["keyboard.dismiss"].tap()
        assertDisappears(app.keyboards.firstMatch)
        let description = app.textViews["task.description"]
        description.tap()
        description.typeText("First line\nSecond line")
        app.buttons["keyboard.dismiss"].tap()
        assertDisappears(app.keyboards.firstMatch)
        XCTAssertTrue((description.value as? String)?.contains("\n") == true)
        XCTAssertTrue(app.navigationBars["New Task"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["task.emptyActive"].waitForExistence(timeout: 3))
    }

    func testInteractiveKeyboardDismissalKeepsTaskDraftWithoutSaving() {
        launchEmptyActive()
        app.buttons["task.add"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        let title = app.textFields["task.title"]
        title.tap()
        title.typeText("Unsubmitted task draft")
        dismissKeyboardByDraggingForm()
        XCTAssertEqual(title.value as? String, "Unsubmitted task draft")
        XCTAssertTrue(app.navigationBars["New Task"].exists)

        let description = app.textViews["task.description"]
        for _ in 0..<3 where !description.isHittable { app.collectionViews.firstMatch.swipeUp() }
        description.tap()
        description.typeText("First line\nSecond line")
        dismissKeyboardByDraggingForm()
        XCTAssertEqual(description.value as? String, "First line\nSecond line")
        XCTAssertTrue(app.navigationBars["New Task"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["task.emptyActive"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Complete Unsubmitted task draft"].exists)
    }

    func testInteractiveKeyboardDismissalKeepsNewGroupDraftWithoutCreatingIt() {
        launchEmptyActive()
        openNewTask(title: "Draft with group")
        let picker = app.buttons["task.group"]
        picker.tap()
        app.buttons["New group"].tap()
        XCTAssertTrue(app.navigationBars["New group"].waitForExistence(timeout: 3))
        let name = app.textFields["group.name"]
        name.tap()
        name.typeText("Unsubmitted group")
        dismissKeyboardByDraggingForm()
        XCTAssertEqual(name.value as? String, "Unsubmitted group")
        XCTAssertTrue(app.buttons["group.create"].isEnabled)
        app.navigationBars["New group"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 3))
        XCTAssertFalse((picker.label + " " + String(describing: picker.value)).contains("Unsubmitted group"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["task.emptyActive"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Complete Draft with group"].exists)
    }

    func testGroupSelectorCreatesSelectsAndCancelsNewGroups() {
        launchEmptyActive()
        app.buttons["tab.settings"].tap()
        app.buttons["appearance.light"].tap()
        app.buttons["tab.active"].tap()
        openNewTask(title: "Grouped task")
        XCTAssertFalse(app.textFields["New group"].exists)
        let picker = app.buttons["task.group"]
        picker.tap()
        app.buttons["New group"].tap()
        XCTAssertTrue(app.navigationBars["New group"].waitForExistence(timeout: 3))
        app.textFields["group.name"].tap()
        app.textFields["group.name"].typeText("Weekend plans")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "New group form in light appearance"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["group.create"].tap()
        assertDisappears(app.navigationBars["New group"])
        XCTAssertTrue((picker.label + " " + String(describing: picker.value)).contains("Weekend plans"))
        picker.tap()
        app.buttons["New group"].tap()
        app.textFields["group.name"].tap()
        app.textFields["group.name"].typeText("Weekend plans")
        XCTAssertFalse(app.buttons["group.create"].isEnabled)
        app.navigationBars["New group"].buttons["Cancel"].tap()
        XCTAssertTrue((picker.label + " " + String(describing: picker.value)).contains("Weekend plans"))
        app.buttons["task.save"].tap()
        XCTAssertTrue(app.buttons["Complete Grouped task"].waitForExistence(timeout: 3))
        app.buttons["Task details: Grouped task"].tap()
        XCTAssertTrue((picker.label + " " + String(describing: picker.value)).contains("Weekend plans"))
    }

    func testWeeklyReminderOffersWeekdayAndTimeAndKeepsSelection() {
        launchEmptyActive()
        openNewTask(title: "Weekly reminder check")
        let enabled = app.switches["reminder.enabled"]
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(enabled.value as? String, "1")
        app.segmentedControls["reminder.frequency"].buttons["Weekly"].tap()
        let day = app.buttons["reminder.weekday"]
        XCTAssertTrue(day.waitForExistence(timeout: 3))
        day.tap()
        app.buttons[Calendar.current.weekdaySymbols[5]].tap()
        XCTAssertTrue(app.datePickers["reminder.time"].exists)
        app.buttons["task.save"].tap()
        XCTAssertTrue(app.buttons["Complete Weekly reminder check"].waitForExistence(timeout: 3))
        app.buttons["Task details: Weekly reminder check"].tap()
        app.collectionViews.firstMatch.swipeUp()
        XCTAssertTrue(app.segmentedControls["reminder.frequency"].buttons["Weekly"].isSelected)
        XCTAssertTrue((day.label + " " + String(describing: day.value)).contains(Calendar.current.weekdaySymbols[5]))
        app.segmentedControls["reminder.frequency"].buttons["Daily"].tap()
        XCTAssertFalse(day.exists)
        app.segmentedControls["reminder.frequency"].buttons["Weekly"].tap()
        XCTAssertTrue((day.label + " " + String(describing: day.value)).contains(Calendar.current.weekdaySymbols[5]))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Weekly reminder weekday and time"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
