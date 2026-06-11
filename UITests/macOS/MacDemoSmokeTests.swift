import XCTest

/// Demo-mode smoke test for the Mac app: window appears, tabs work.
final class MacDemoSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoHouseLoads() throws {
        let app = Snap.demoApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Party House"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["zone-card-Living Room"].firstMatch.waitForExistence(timeout: 5))

        app.buttons["Gradients"].firstMatch.click()
        XCTAssertTrue(app.buttons["import-gradient"].waitForExistence(timeout: 5))
    }
}
