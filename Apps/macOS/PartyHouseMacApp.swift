import SwiftUI
import AppKit
import PartyCore
import PartyUI

@main
struct PartyHouseMacApp: App {
    @State private var appEnvironment = AppEnvironment()
    @AppStorage("hideDockIcon") private var hideDockIcon = false
    @AppStorage("menuBarExtraShown") private var menuBarExtraShown = true

    private var reconnect: ReconnectAction {
        ReconnectAction { [appEnvironment] in
            await appEnvironment.reloadProviders()
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(initialTab: appEnvironment.initialTab)
                .environment(appEnvironment.lightsStore)
                .environment(\.partyReconnect, reconnect)
                .task {
                    await appEnvironment.start()
                    DockIconController.apply(hidden: hideDockIcon)
                    ScreenshotWindowSizer.applyIfNeeded()
                }
                .onChange(of: hideDockIcon) {
                    DockIconController.apply(hidden: hideDockIcon)
                }
        }
        .defaultSize(width: 1100, height: 760)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("Party House", systemImage: "party.popper.fill", isInserted: $menuBarExtraShown) {
            MenuBarContentView()
                .environment(appEnvironment.lightsStore)
                .environment(\.partyReconnect, reconnect)
                .task {
                    await appEnvironment.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appEnvironment.lightsStore)
                .environment(\.partyReconnect, reconnect)
                .frame(minWidth: 540, minHeight: 480)
                .partyAppearance()
        }
    }
}
