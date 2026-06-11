import XCTest

/// Tiny screenshot helper: numbered, named attachments that survive in the
/// .xcresult bundle so Scripts/extract-screenshots.sh can pull them out.
/// (Also compatible with `fastlane snapshot` runs that scrape attachments.)
enum Snap {
    static func shot(_ name: String, app: XCUIApplication, testCase: XCTestCase) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }

    #if os(macOS)
    /// Captures just the app's main window (clean edges for the Mac App Store).
    static func windowShot(_ name: String, app: XCUIApplication, testCase: XCTestCase) {
        let window = app.windows.firstMatch
        let screenshot = window.exists ? window.screenshot() : app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
    #endif

    /// Identifier lookup that doesn't care how SwiftUI exposes the element
    /// (Button vs otherElement varies by container and OS release).
    static func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    static func demoApp(scene: String = "home", extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-Demo", "YES",
            "-DemoScene", scene,
            "-DisableCloudSync",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launchArguments += extraArguments
        return app
    }
}
