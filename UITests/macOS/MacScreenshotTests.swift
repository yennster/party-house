import XCTest

/// Mac App Store screenshots. `-ScreenshotMode` pins the window to 1440x900 points
/// so Retina captures land on Apple's 2880x1800 size.
/// Run via Scripts/screenshots-macos.sh.
final class MacScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = Snap.demoApp(extraArguments: ["-ScreenshotMode"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Party House"].firstMatch.waitForExistence(timeout: 10))
        sleep(2) // window sizing + glass settle

        // 01 — Home with zone cards.
        Snap.windowShot("01-home", app: app, testCase: self)

        // 02 — Zone detail with gradient applied.
        app.buttons["zone-card-Living Room"].firstMatch.click()
        if app.buttons["zone-all-on"].waitForExistence(timeout: 5) {
            let palette = app.buttons["palette-Neon Nights"].firstMatch
            if palette.exists { palette.click() }
            sleep(1)
            Snap.windowShot("02-zone-gradient", app: app, testCase: self)
        }

        // 03 — Gradients gallery.
        app.buttons["Gradients"].firstMatch.click()
        if app.buttons["import-gradient"].waitForExistence(timeout: 5) {
            sleep(1)
            Snap.windowShot("03-gradients", app: app, testCase: self)
        }

        // 04 — Settings.
        app.buttons["Settings"].firstMatch.click()
        if app.buttons["settings-hue"].waitForExistence(timeout: 5) {
            sleep(1)
            Snap.windowShot("04-settings", app: app, testCase: self)
        }
    }
}
