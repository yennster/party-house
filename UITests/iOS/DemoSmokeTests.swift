import XCTest

/// Fast demo-mode smoke test for CI: the app launches, shows the demo house, and
/// the main tabs respond.
final class DemoSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoHouseLoads() throws {
        let app = Snap.demoApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Party House"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["zone-card-Living Room"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["everything-off"].firstMatch.exists)

        app.buttons["Gradients"].firstMatch.tap()
        XCTAssertTrue(app.buttons["import-gradient"].waitForExistence(timeout: 5))

        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["settings-hue"].waitForExistence(timeout: 5))
    }
}
