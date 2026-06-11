import AppKit

/// Switches the app between a regular Dock app and a menubar-only accessory.
@MainActor
enum DockIconController {
    static func apply(hidden: Bool) {
        NSApp.setActivationPolicy(hidden ? .accessory : .regular)
        if !hidden {
            NSApp.activate(ignoringOtherApps: false)
        }
    }
}

/// Under `-ScreenshotMode`, pins the main window to exactly 1440x900 points so a
/// Retina (2x) capture lands on Apple's 2880x1800 Mac App Store screenshot size.
@MainActor
enum ScreenshotWindowSizer {
    static func applyIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let window = NSApp.windows.first(where: { $0.isVisible && !$0.title.isEmpty }) ?? NSApp.windows.first else { return }
            window.setFrame(
                NSRect(x: 80, y: 80, width: 1440, height: 900),
                display: true,
                animate: false
            )
        }
    }
}
