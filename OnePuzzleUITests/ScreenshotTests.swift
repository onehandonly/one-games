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

        // Welcome -> How it works (retry the Continue tap until it advances)
        var attempts = 0
        while app.buttons["Continue"].waitForExistence(timeout: 10) && attempts < 4 {
            let c = app.buttons["Continue"]
            if c.isHittable { c.tap() }
            sleep(1)
            attempts += 1
            if !app.buttons["Continue"].exists { break }
        }
        sleep(1)
        snapshot("02HowItWorks")

        // How it works -> today's puzzle
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start'")).firstMatch
        if start.waitForExistence(timeout: 15) { start.tap() }
        sleep(2)

        func type(_ s: String) {
            for ch in s {
                let k = app.buttons[String(ch)]
                if k.waitForExistence(timeout: 3) { k.tap(); usleep(250_000) }
            }
        }
        type("HOUSE")
        let enter = app.buttons["Enter"]
        if enter.waitForExistence(timeout: 3) { enter.tap() }
        sleep(1)
        type("TRI")
        sleep(1)
        snapshot("03Puzzle")
    }
}
