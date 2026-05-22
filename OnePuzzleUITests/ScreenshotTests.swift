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

        // 01 — Welcome: let the typewriter animation settle first
        sleep(3)
        snapshot("01Welcome")

        // -> How it works
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 15) { cont.tap() }
        sleep(1)
        snapshot("02HowItWorks")

        // -> Today's puzzle
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start'")).firstMatch
        if start.waitForExistence(timeout: 15) { start.tap() }
        sleep(1)

        // Make the board look active: submit one guess (colorful feedback) + start a second
        func type(_ s: String) {
            for ch in s {
                let key = app.buttons[String(ch)]
                if key.waitForExistence(timeout: 3) { key.tap() }
            }
        }
        type("AUDIO")
        let enter = app.buttons["Enter"]
        if enter.exists { enter.tap() }
        sleep(1)
        type("STA")
        sleep(1)
        snapshot("03Puzzle")
    }
}
