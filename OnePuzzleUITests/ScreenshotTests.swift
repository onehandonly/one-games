import XCTest

final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // 01 — Welcome / onboarding
        snapshot("01Welcome")

        // Welcome -> How it works
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 15) { cont.tap() }
        snapshot("02HowItWorks")

        // How it works -> Today's puzzle
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start'")).firstMatch
        if start.waitForExistence(timeout: 15) { start.tap() }
        snapshot("03Puzzle")
    }
}
