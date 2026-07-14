import XCTest

/// Visible capture contracts for the native Understood shell.
///
/// These tests deliberately exercise the same flow Adam uses: open the bolt,
/// choose a destination, save a titled entry, then relaunch and verify the
/// local-first cache restores it in the destination feed.
final class UnderstoodCaptureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitestBypassAuth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testReminderCaptureSurvivesRelaunch() {
        let title = "UI Test Reminder " + String(Int(Date().timeIntervalSince1970))
        capture(title: title, destination: "Reminder")
        openSection("Reminders")
        assertEntryVisible(title)

        app.terminate()
        app.launch()
        openSection("Reminders")
        assertEntryVisible(title)
    }

    func testActionCaptureSurvivesRelaunch() {
        let title = "UI Test Action " + String(Int(Date().timeIntervalSince1970))
        capture(title: title, destination: "Action")
        openSection("Actions")
        assertEntryVisible(title)

        app.terminate()
        app.launch()
        openSection("Actions")
        assertEntryVisible(title)
    }

    private func capture(title: String, destination: String) {
        let fab = app.buttons["chargeFab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 15), "New entry button missing")
        fab.tap()

        let destinationButton = app.buttons[destination]
        XCTAssertTrue(destinationButton.waitForExistence(timeout: 10), destination + " capture option missing")
        destinationButton.tap()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Capture form did not open")
        titleField.tap()
        titleField.typeText(title)

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Save button missing")
        save.tap()
    }

    private func openSection(_ label: String) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 10), label + " tab missing")
        button.tap()
    }

    private func assertEntryVisible(_ title: String) {
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 15), title + " missing from visible feed")
    }
}
