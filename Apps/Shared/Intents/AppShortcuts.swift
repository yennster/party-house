#if !WIDGET_EXTENSION
import AppIntents

/// Surfaces Party House actions in Siri, Spotlight, and the Shortcuts app.
struct PartyHouseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AllOffIntent(),
            phrases: [
                "Turn everything off in \(.applicationName)",
                "\(.applicationName) lights off",
            ],
            shortTitle: "Everything Off",
            systemImageName: "power"
        )
        AppShortcut(
            intent: ToggleZoneIntent(),
            phrases: [
                "Toggle a zone in \(.applicationName)",
            ],
            shortTitle: "Toggle Zone",
            systemImageName: "lamp.ceiling.inverse"
        )
        AppShortcut(
            intent: ApplyPaletteIntent(),
            phrases: [
                "Start the party in \(.applicationName)",
                "Apply a gradient in \(.applicationName)",
            ],
            shortTitle: "Apply Gradient",
            systemImageName: "rainbow"
        )
    }
}
#endif
