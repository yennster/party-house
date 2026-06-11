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

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30))

        let homeTab = Snap.element("Home", in: app)
        if homeTab.waitForExistence(timeout: 10) { homeTab.click() }
        XCTAssertTrue(Snap.element("zone-card-Living Room", in: app).waitForExistence(timeout: 10))

        Snap.element("Gradients", in: app).click()
        XCTAssertTrue(Snap.element("import-gradient", in: app).waitForExistence(timeout: 5))
    }
}
