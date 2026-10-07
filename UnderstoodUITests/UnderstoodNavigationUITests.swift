import XCTest

final class UnderstoodNavigationUITests: XCTestCase {
    func testHomeReturnsFromRemindersAndCowboyAccessIsHidden() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestBypassAuth", "-uitestSection", "connection"]
        app.launch()
        defer { app.terminate() }

        let home = app.buttons["homeBottomNav"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        XCTAssertFalse(home.isSelected)
        XCTAssertFalse(app.buttons["cowboyBottomNav"].exists)
        home.tap()
        XCTAssertTrue(home.isSelected, "Home should return to the Stories screen")

        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.staticTexts["THE ADAM PATTERN"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["COWBOY AI"].exists)
        XCTAssertFalse(app.staticTexts["COWBOY AI"].exists)
    }

    func testOldCowboyRouteCannotExposeTheCowboyScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestBypassAuth", "-uitestSection", "cowboy", "-uitestCowboyResult"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["homeBottomNav"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.otherElements["cowboyAIView"].exists)
        XCTAssertFalse(app.buttons["cowboyWorkerMenu"].exists)
    }
}
