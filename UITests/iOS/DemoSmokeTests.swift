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

        XCTAssertTrue(app.staticTexts["Party House"].waitForExistence(timeout: 30))
        XCTAssertTrue(Snap.element("zone-card-Living Room", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(Snap.element("everything-off", in: app).exists)

        app.buttons["Gradients"].firstMatch.tap()
        XCTAssertTrue(Snap.element("import-gradient", in: app).waitForExistence(timeout: 5))

        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(Snap.element("settings-hue", in: app).waitForExistence(timeout: 5))
    }
}
