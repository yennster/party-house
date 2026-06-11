import SwiftUI
import PartyCore
import PartyUI

@main
struct PartyHouseApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView(initialTab: appEnvironment.initialTab)
                .environment(appEnvironment.lightsStore)
                .environment(
                    \.partyReconnect,
                    ReconnectAction { [appEnvironment] in
                        await appEnvironment.reloadProviders()
                    }
                )
                .task {
                    await appEnvironment.start()
                }
        }
    }
}
