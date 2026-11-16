import XCTest

final class TaskProgressUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-sample-data", "-progress-data", "-ui-testing", "-reset-test-preferences"]
        app.launch()
    }

    private func showSettings() {
        if app.buttons["navigation.expand"].exists { app.buttons["navigation.expand"].tap() }
        app.buttons["tab.settings"].tap()
        let scroll = app.scrollViews["settings.scroll"]
        for _ in 0..<3 where !app.switches["settings.taskProgress"].isHittable { scroll.swipeUp() }
    }

    private func showActive() {
        if app.buttons["navigation.expand"].exists { app.buttons["navigation.expand"].tap() }
        app.buttons["tab.active"].tap()
    }

    private func enableProgress() {
        showSettings()
        let toggle = app.switches["settings.taskProgress"]
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
    }

    private func editLabels() {
        let button = app.buttons["settings.progressLabels"]
        if !button.isHittable { app.scrollViews["settings.scroll"].swipeUp() }
        button.tap()
        XCTAssertTrue(app.navigationBars["Progress labels"].waitForExistence(timeout: 3))
    }

    private func labelField() -> XCUIElement {
        let view = app.textViews["progress.labelName"]
        return view.exists ? view : app.textFields["progress.labelName"]
    }

    private func addLabel(_ label: String) {
        let add = app.buttons["progress.addLabel"]
        for _ in 0..<5 where !add.isHittable { app.collectionViews.firstMatch.swipeUp() }
        add.tap()
        XCTAssertTrue(app.navigationBars["New label"].waitForExistence(timeout: 3))
        let field = labelField()
        field.tap()
        field.typeText(label)
        app.buttons["progress.saveLabel"].tap()
        let created = app.buttons["Edit \(label)"]
        for _ in 0..<4 where !created.exists { app.collectionViews.firstMatch.swipeDown() }
        XCTAssertTrue(created.waitForExistence(timeout: 3))
    }

    private func saveLabels() {
        app.buttons["progress.saveLabels"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["Progress labels"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
        XCTAssertTrue(app.buttons["settings.progressLabels"].exists)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testProgressStartsOffAndExpandsLabelsOnlyWhenEnabled() {
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertFalse(app.sliders["task.progressSlider"].exists)
        app.buttons["Cancel"].tap()
        showSettings()
        XCTAssertEqual(app.switches["settings.taskProgress"].value as? String, "0")
        XCTAssertFalse(app.buttons["settings.progressLabels"].exists)
        let toggle = app.switches["settings.taskProgress"]
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["To do"].exists)
        XCTAssertTrue(app.staticTexts["In progress"].exists)
        screenshot("Expanded task progress settings")
        showActive()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'task.progress.'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Complete Plan the week"].exists)
    }

    func testDetailSliderChangesLabelWithoutCompletingAndDisableRetainsIt() {
        enableProgress()
        showActive()
        app.buttons["Task details: Plan the week"].tap()
        let slider = app.sliders["task.progressSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 3))
        slider.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "In progress")
        screenshot("Stepped progress slider in task details")
        app.buttons["task.save"].tap()
        XCTAssertTrue(app.buttons["Complete Plan the week"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(app.buttons["Complete Plan the week"].frame.midY, app.buttons["Complete Review the project notes"].frame.midY)
        showSettings()
        let toggle = app.switches["settings.taskProgress"]
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        showActive()
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertFalse(slider.exists)
        app.buttons["Cancel"].tap()
        enableProgress()
        showActive()
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "In progress")
    }

    func testDragIntoEmptyProgressSectionChangesLabelAndCanReturn() {
        enableProgress()
        showActive()
        let sectionID = "progress.section.2AD6EE26-6CE2-599C-A474-B493C1AFD50A.00000000-0000-0000-0000-000000000002"
        let target = app.staticTexts[sectionID]
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        let start = app.buttons["Task details: Plan the week"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertTrue(app.buttons["tab.active"].exists)
        XCTAssertFalse(app.buttons["navigation.expand"].exists)
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "In progress")
        app.buttons["Cancel"].tap()
        screenshot("Task moved into In progress by dragging")
        let todoID = "progress.section.2AD6EE26-6CE2-599C-A474-B493C1AFD50A.00000000-0000-0000-0000-000000000001"
        let back = app.buttons["Task details: Plan the week"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        back.press(forDuration: 0.15, thenDragTo: app.staticTexts[todoID].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "To do")
    }

    func testDraggingBetweenTaskGroupsMovesTheTaskAndAppliesTheTargetLabel() {
        enableProgress()
        showActive()
        let personal = app.staticTexts["task.groupHeader.9AF80E3E-F57D-5B52-9F0C-5BB30350F75F"]
        let first = app.buttons["Task details: Plan the week"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        first.press(forDuration: 0.15, thenDragTo: personal.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertTrue(app.navigationBars["Task Details"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["task.group"].label.contains("Personal"))
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "To do")
        app.buttons["Cancel"].tap()
        let target = app.staticTexts["progress.section.9AF80E3E-F57D-5B52-9F0C-5BB30350F75F.00000000-0000-0000-0000-000000000002"]
        if target.frame.midY > app.otherElements["navigation.bar"].frame.minY - 8 {
            let list = app.scrollViews["taskList.active"]
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.75))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.68))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        let second = app.buttons["Task details: Review the project notes"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        second.press(forDuration: 0.15, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        app.buttons["Task details: Review the project notes"].tap()
        XCTAssertTrue(app.buttons["task.group"].label.contains("Personal"))
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "In progress")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Complete Review the project notes"].exists)
        screenshot("Nested progress sections after moving between task groups")
    }

    func testLabelEditorCanAddRenameReorderAndCancelDrafts() {
        enableProgress()
        editLabels()
        addLabel("Draft")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Draft"].exists)
        editLabels()
        addLabel("Draft")
        app.buttons["Edit To do"].tap()
        XCTAssertTrue(app.navigationBars["Edit label"].waitForExistence(timeout: 3))
        let field = labelField()
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "Queued")
        app.buttons["progress.saveLabel"].tap()
        app.buttons["Edit"].tap()
        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'"))
        XCTAssertEqual(handles.count, 3)
        let start = handles.element(boundBy: 2).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = handles.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.3, thenDragTo: end)
        screenshot("Editable and reorderable progress labels")
        saveLabels()
        XCTAssertLessThan(app.staticTexts["Draft"].frame.midY, app.staticTexts["In progress"].frame.midY)
        let startingLabel = app.staticTexts["Draft"].frame.midY < app.staticTexts["Queued"].frame.midY ? "Draft" : "Queued"
        showActive()
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "Queued")
        app.buttons["Cancel"].tap()
        app.buttons["task.add"].tap()
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, startingLabel)
    }

    func testProgressLabelsAndSliderRemainReadableInLightAccessibilityLayout() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        app.buttons["tab.settings"].tap()
        app.buttons["appearance.light"].tap()
        enableProgress()
        editLabels()
        let label = "Waiting for another look"
        addLabel(label)
        saveLabels()
        showActive()
        app.buttons["Task details: Plan the week"].tap()
        let slider = app.sliders["task.progressSlider"]
        for _ in 0..<4 where !slider.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(slider.isHittable)
        slider.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, label)
        XCTAssertTrue(slider.isHittable, "Changing a label must not push the slider offscreen")
        let form = app.collectionViews.firstMatch
        for _ in 0..<3 where app.staticTexts["task.progressLabel"].frame.maxY > form.frame.maxY - 16 {
            let start = form.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.85))
            let end = form.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        screenshot("Light progress details at accessibility text size")
        app.buttons["task.save"].tap()
        XCTAssertTrue(app.buttons["Complete Plan the week"].waitForExistence(timeout: 3))
    }

    func testCustomLabelCanReplaceBothDefaultsAndSingleLabelHasNoSlider() {
        enableProgress()
        editLabels()
        addLabel("Working")
        app.buttons["Edit"].tap()
        for suffix in ["1", "2"] {
            let id = "progress.label.00000000-0000-0000-0000-00000000000\(suffix)"
            let row = app.collectionViews.firstMatch.cells.containing(.any, identifier: id).firstMatch
            XCTAssertTrue(row.exists)
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
            let delete = app.buttons.matching(NSPredicate(format: "label == 'Delete' OR label BEGINSWITH 'Delete '")).firstMatch
            if delete.exists { delete.tap() }
            XCTAssertFalse(row.exists)
        }
        saveLabels()
        showActive()
        app.buttons["Task details: Plan the week"].tap()
        XCTAssertEqual(app.staticTexts["task.progressLabel"].label, "Working")
        XCTAssertFalse(app.sliders["task.progressSlider"].exists)
    }
}
