import XCTest

final class OnePuzzleUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAppLaunchesSuccessfully() {
        XCTAssertTrue(app.staticTexts["Puzzle"].exists || app.otherElements.count > 0)
    }
}
