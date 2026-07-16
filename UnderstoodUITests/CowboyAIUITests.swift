import XCTest

/// Visible Cowboy AI contracts: the supplied hat is a real navigation control and
/// the worker chooser exposes the personal, deeper-local, and frontier routes.
final class CowboyAIUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitestBypassAuth", "-uitestSection", "story", "-uitestCowboyResult"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testHatOpensCowboyAndWorkerRoutesAreVisible() {
        let hat = app.buttons["cowboyBottomNav"]
        XCTAssertTrue(hat.waitForExistence(timeout: 15), "Cowboy hat is missing from bottom-left navigation")
        hat.tap()

        XCTAssertTrue(app.staticTexts["COWBOY AI"].waitForExistence(timeout: 10), "Cowboy AI screen did not open")

        let workerMenu = app.buttons["cowboyWorkerMenu"]
        XCTAssertTrue(workerMenu.waitForExistence(timeout: 10), "Worker chooser is missing")
        workerMenu.tap()

        XCTAssertTrue(app.buttons["cowboyWorkerOption-reason"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cowboyWorkerOption-deep_local"].exists)
        XCTAssertTrue(app.buttons["cowboyWorkerOption-frontier_claude"].exists)
        XCTAssertTrue(app.buttons["cowboyWorkerOption-frontier_codex"].exists)
    }
}
