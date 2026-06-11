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

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30))
        sleep(2) // window sizing + glass settle

        // 01 — Home with zone cards.
        let homeTab = Snap.element("Home", in: app)
        if homeTab.waitForExistence(timeout: 10) { homeTab.click() }
        XCTAssertTrue(Snap.element("zone-card-Living Room", in: app).waitForExistence(timeout: 10))
        sleep(1)
        Snap.windowShot("01-home", app: app, testCase: self)

        // 02 — Zone detail with gradient applied. Click the left side of the card so
        // the click can't land on the power toggle.
        let livingRoomCard = Snap.element("zone-card-Living Room", in: app)
        livingRoomCard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        if Snap.element("zone-all-on", in: app).waitForExistence(timeout: 5) {
            let palette = Snap.element("palette-Neon Nights", in: app)
            if palette.exists { palette.click() }
            sleep(1)
            Snap.windowShot("02-zone-gradient", app: app, testCase: self)
        }

        // 03 — Gradients gallery.
        Snap.element("Gradients", in: app).click()
        if Snap.element("import-gradient", in: app).waitForExistence(timeout: 5) {
            sleep(1)
            Snap.windowShot("03-gradients", app: app, testCase: self)
        }

        // 04 — Settings.
        Snap.element("Settings", in: app).click()
        if Snap.element("settings-hue", in: app).waitForExistence(timeout: 5) {
            sleep(1)
            Snap.windowShot("04-settings", app: app, testCase: self)
        }
    }
}
