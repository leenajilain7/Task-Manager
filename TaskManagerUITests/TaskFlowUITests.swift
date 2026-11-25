import XCTest

@MainActor
final class TaskFlowUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    private func createTask(named title: String, in app: XCUIApplication) {
        let addButton = app.buttons["Add task"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let titleField = app.textFields["task.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        app.buttons["task.save"].tap()
    }

    func testLaunchAndNavigateBetweenAllTabs() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Add task"].waitForExistence(timeout: 5))

        let tabs = app.tabBars.buttons
        XCTAssertTrue(tabs["Home"].exists)
        tabs["Tasks"].tap()
        XCTAssertTrue(app.navigationBars["All Tasks"].waitForExistence(timeout: 5))
        tabs["Statistics"].tap()
        XCTAssertTrue(app.navigationBars["Statistics"].waitForExistence(timeout: 5))
        tabs["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        tabs["Home"].tap()
        XCTAssertTrue(app.buttons["Add task"].exists)
    }

    func testCreateSearchAndSwitchTaskFilters() {
        let app = launchApp()
        let title = "UI Test Search Sample"
        createTask(named: title, in: app)

        app.tabBars.buttons["Tasks"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("search sample")
        XCTAssertTrue(app.buttons["task.row.\(title)"].waitForExistence(timeout: 5))

        let clearSearch = searchField.buttons.firstMatch
        if clearSearch.exists { clearSearch.tap() }

        let filters = app.segmentedControls["tasks.statusFilter"]
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        filters.buttons["Pending"].tap()
        XCTAssertTrue(app.buttons["task.row.\(title)"].waitForExistence(timeout: 5))
        filters.buttons["Completed"].tap()
        XCTAssertTrue(app.staticTexts["No completed tasks"].waitForExistence(timeout: 5))
        filters.buttons["All"].tap()
        XCTAssertTrue(app.buttons["task.row.\(title)"].waitForExistence(timeout: 5))
    }

    func testDetailsEditCompletionAndConfirmedDeletion() {
        let app = launchApp()
        let title = "UI Test Lifecycle Sample"
        createTask(named: title, in: app)
        app.tabBars.buttons["Tasks"].tap()

        let taskRow = app.buttons["task.row.\(title)"]
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))
        taskRow.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))

        app.buttons["task.actions"].tap()
        app.buttons["Edit task"].tap()
        let descriptionField = app.textFields["task.description"]
        XCTAssertTrue(descriptionField.waitForExistence(timeout: 5))
        descriptionField.tap()
        descriptionField.typeText("Updated by UI test")
        app.buttons["task.save"].tap()
        XCTAssertTrue(app.staticTexts["Updated by UI test"].waitForExistence(timeout: 5))

        app.buttons["task.toggleCompletion"].tap()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 5))

        app.buttons["task.actions"].tap()
        app.buttons["Delete task"].tap()
        let confirmDelete = app.buttons["task.confirmDelete"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()
        XCTAssertFalse(app.buttons["task.row.\(title)"].waitForExistence(timeout: 2))
    }

    func testReminderCanBeEnabledAndAppearsInTaskDetails() {
        let app = launchApp()
        let title = "UI Reminder Sample"
        app.buttons["Add task"].tap()
        let titleField = app.textFields["task.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)

        let reminderToggle = app.switches["task.reminderEnabled"].switches.firstMatch
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5))
        reminderToggle.tap()
        let clearReminder = app.buttons["task.clearReminder"]
        XCTAssertTrue(clearReminder.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["task.save"].tap()

        app.tabBars.buttons["Tasks"].tap()
        let taskRow = app.buttons["task.row.\(title)"]
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))
        taskRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["task.reminderDetails"].waitForExistence(timeout: 5))
    }

    func testSettingsExplainsNotificationPermissionBeforeRequest() {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let explanation = app.staticTexts["TaskFlow uses notifications to alert you at the reminder time you choose."]
        for _ in 0..<5 where !explanation.exists {
            app.swipeUp()
        }
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Permission status"].exists || app.otherElements["settings.notificationStatus"].exists)
        XCTAssertTrue(
            app.buttons["settings.requestNotifications"].exists ||
            app.buttons["settings.openNotificationSettings"].exists ||
            app.staticTexts["Task reminders can be delivered."].exists ||
            app.staticTexts["Notification access is restricted by this device’s settings."].exists
        )
    }
}
