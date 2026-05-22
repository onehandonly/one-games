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

        sleep(3)
        snapshot("01Welcome")

        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 15) { cont.tap() }
        sleep(1)
        snapshot("02HowItWorks")

        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start'")).firstMatch
        if start.waitForExistence(timeout: 15) { start.tap() }
        sleep(1)

        // Type letters one at a time with a settle, avoiding edge keys; submit for colorful feedback.
        func type(_ s: String) {
            for ch in s {
                let key = app.buttons[String(ch)]
                if key.waitForExistence(timeout: 3) { key.tap(); usleep(250_000) }
            }
        }
        type("HOUSE")          // no left-edge keys; 5 letters
        let enter = app.buttons["Enter"]
        if enter.waitForExistence(timeout: 3) { enter.tap() }
        sleep(1)
        type("TRI")            // partial second guess, middle keys only
        sleep(1)
        snapshot("03Puzzle")
    }
}
