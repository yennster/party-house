import SwiftUI
import PartyCore

/// Shared root for iPhone, iPad, and the Mac main window.
public struct RootView: View {
    @Environment(LightsStore.self) private var store

    @State private var selectedTab: TabID

    public enum TabID: String {
        case home, gradients, settings
    }

    public init(initialTab: TabID = .home) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: TabID.home) {
                HomeView()
            }
            Tab("Gradients", systemImage: "rainbow", value: TabID.gradients) {
                GradientsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: TabID.settings) {
                SettingsView()
            }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .tint(PartyTheme.accent)
    }
}
