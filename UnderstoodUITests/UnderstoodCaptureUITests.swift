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
        app.launchArguments = ["-uitestBypassAuth", "-uitestResetStore"]
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
        app.launchArguments = ["-uitestBypassAuth"]
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
        app.launchArguments = ["-uitestBypassAuth"]
        app.launch()
        openSection("Actions")
        assertEntryVisible(title)
    }

    func testThemesAreFirstInEveryFABForm() {
        for destination in ["Reminder", "Action", "Event"] {
            openComposer(destination: destination)
            let theme = app.buttons["Theme"]
            XCTAssertTrue(theme.waitForExistence(timeout: 5), "Theme missing for \(destination)")
            let answer = themeAnswer(0)
            XCTAssertTrue(answer.exists)
            XCTAssertLessThan(theme.frame.minY, answer.frame.minY)
            XCTAssertTrue((answer.value as? String ?? "").contains("What happened?"))
            app.buttons["Cancel"].tap()
        }
    }

    func testThemeAnswersSurviveSwitchingSavingAndRelaunch() {
        let title = "UI Theme Verification " + String(Int(Date().timeIntervalSince1970))
        openComposer(destination: "Reminder")
        let titleField = app.textFields["Title"]
        reveal(titleField)
        titleField.tap()
        titleField.typeText(title)
        selectTheme("Problem → Solution")
        let answer = themeAnswer(0)
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        XCTAssertTrue((answer.value as? String ?? "").contains("What's the problem?"))
        answer.tap()
        answer.typeText("A retained answer across theme changes.")
        let fullAnswer = answer.value as? String

        selectTheme("The 5 Ws")
        selectTheme("Problem → Solution")
        XCTAssertEqual(themeAnswer(0).value as? String, fullAnswer)

        app.buttons["Save"].tap()
        openSection("Reminders")
        assertEntryVisible(title)

        app.terminate()
        app.launchArguments = ["-uitestBypassAuth", "-uitestSection", "connection"]
        app.launch()
        let entry = app.staticTexts[title]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.tap()
        XCTAssertTrue(app.buttons["Theme"].waitForExistence(timeout: 5))
        let selectedTheme = app.buttons["Theme"]
        XCTAssertTrue((selectedTheme.label + " " + (selectedTheme.value as? String ?? "")).contains("Problem → Solution"))
        XCTAssertEqual(themeAnswer(0).value as? String, fullAnswer)
        app.buttons["Cancel"].tap()
    }

    private func capture(title: String, destination: String) {
        openComposer(destination: destination)
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Capture form did not open")
        reveal(titleField)
        titleField.tap()
        titleField.typeText(title)

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Save button missing")
        save.tap()
    }

    private func openComposer(destination: String) {
        let fab = app.buttons["chargeFab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 15), "New entry button missing")
        fab.tap()
        let destinationButton = app.buttons[destination]
        if destinationButton.waitForExistence(timeout: 3) {
            destinationButton.tap()
        } else {
            // Keep a geometry fallback for older simulator accessibility hosts.
            let start = fab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let offset: CGVector = switch destination {
            case "Action": CGVector(dx: 0, dy: -120)
            case "Event": CGVector(dx: 90, dy: -40)
            default: CGVector(dx: -90, dy: -40)
            }
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(offset))
        }

        XCTAssertTrue(app.buttons["Theme"].waitForExistence(timeout: 10), "Capture form did not open")
    }

    private func themeAnswer(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "themeAnswer\(index)").firstMatch
    }

    private func selectTheme(_ name: String) {
        let picker = app.buttons["Theme"]
        for _ in 0..<5 where !picker.isHittable { app.swipeDown() }
        picker.tap()
        let option = app.buttons[name]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
    }

    private func reveal(_ field: XCUIElement) {
        for _ in 0..<6 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.isHittable, "Field is not reachable by scrolling")
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
