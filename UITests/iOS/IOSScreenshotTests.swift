import XCTest

/// Drives the demo house through the App Store screenshot set.
/// Run via Scripts/screenshots-ios.sh (or fastlane snapshot locally).
final class IOSScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = Snap.demoApp()
        app.launch()

        // 01 — Home: zone cards.
        XCTAssertTrue(app.staticTexts["Party House"].waitForExistence(timeout: 10))
        sleep(1)
        Snap.shot("01-home", app: app, testCase: self)

        // 02 — Zone detail: lights grid + palette row.
        app.buttons["zone-card-Living Room"].firstMatch.tap()
        XCTAssertTrue(app.buttons["zone-all-on"].waitForExistence(timeout: 5))
        sleep(1)
        Snap.shot("02-zone", app: app, testCase: self)

        // 03 — Gradient applied to the zone.
        let palette = app.buttons["palette-Neon Nights"].firstMatch
        if palette.waitForExistence(timeout: 3) {
            palette.tap()
            sleep(1)
        }
        Snap.shot("03-zone-gradient", app: app, testCase: self)

        // 04 — Gradients gallery.
        app.buttons["Gradients"].firstMatch.tap()
        XCTAssertTrue(app.buttons["import-gradient"].waitForExistence(timeout: 5))
        sleep(1)
        Snap.shot("04-gradients", app: app, testCase: self)

        // 05 — Settings: integrations.
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["settings-hue"].waitForExistence(timeout: 5))
        sleep(1)
        Snap.shot("05-settings", app: app, testCase: self)
    }
}
