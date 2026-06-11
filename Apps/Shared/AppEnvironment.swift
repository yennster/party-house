import Foundation
import Observation
import PartyCore
import PartyHue
import PartyHomeAssistant
import PartyLIFX
import PartyUI

/// Composition root shared by the iOS and macOS apps: builds stores, constructs
/// providers from synced configuration, and seeds the demo house when launched
/// with `-Demo YES` (previews, UI tests, App Store screenshots).
@MainActor
@Observable
final class AppEnvironment {
    let zoneStore: ZoneStore
    let lightsStore: LightsStore
    let isDemo: Bool

    private var started = false

    var initialTab: RootView.TabID {
        switch UserDefaults.standard.string(forKey: "DemoScene") {
        case "gradients": return .gradients
        case "settings": return .settings
        default: return .home
        }
    }

    init() {
        let demo = UserDefaults.standard.bool(forKey: "Demo")
        isDemo = demo

        let sync: SyncEngine
        if demo {
            // Demo state lives in its own suite so it never pollutes real config.
            let defaults = UserDefaults(suiteName: "io.github.yennster.partyhouse.demo")!
            defaults.removePersistentDomain(forName: "io.github.yennster.partyhouse.demo")
            sync = SyncEngine(defaults: defaults, cloudEnabled: false)
        } else {
            sync = .shared
        }

        zoneStore = ZoneStore(sync: sync)
        lightsStore = LightsStore(zoneStore: zoneStore, sync: sync)
    }

    func start() async {
        guard !started else { return }
        started = true

        if isDemo {
            await startDemo()
        } else {
            await reloadProviders()
        }
    }

    /// Tears down and rebuilds all providers from the current (synced) config.
    /// Called on launch, after any setup-sheet change, and when iCloud delivers
    /// config from another device.
    func reloadProviders() async {
        guard !isDemo else { return }
        let configs = ProviderConfigs.load()

        var desired: Set<ProviderID> = []
        for bridge in configs.hueBridges {
            desired.insert(.hue(bridgeID: bridge.bridgeID))
        }
        if configs.homeAssistant != nil { desired.insert(.homeAssistant) }
        if configs.lifx.enabled { desired.insert(.lifx) }

        for existing in lightsStore.connectedProviders where !desired.contains(existing) {
            await lightsStore.remove(providerID: existing)
        }

        for bridge in configs.hueBridges {
            guard let key = KeychainStore.read(.hueApplicationKey, account: bridge.bridgeID) else { continue }
            await lightsStore.register(
                HueProvider(bridgeID: bridge.bridgeID, host: bridge.host, applicationKey: key)
            )
        }

        if let haConfig = configs.homeAssistant,
           let token = KeychainStore.read(.homeAssistantToken) {
            await lightsStore.register(HAProvider(config: haConfig, token: token))
        }

        if configs.lifx.enabled {
            await lightsStore.register(LIFXProvider(manualHosts: configs.lifx.manualHosts))
        }
    }

    // MARK: Demo

    private func startDemo() async {
        let provider = DemoProvider()
        await lightsStore.register(provider)

        guard zoneStore.zones.isEmpty else { return }
        let lights = (try? await provider.lights()) ?? []
        let byRoom = Dictionary(grouping: lights) { $0.room ?? "Other" }

        func zone(_ name: String, symbol: String) -> Zone? {
            guard let members = byRoom[name] else { return nil }
            return Zone(name: name, symbolName: symbol, lightIDs: members.map(\.id))
        }

        for seeded in [
            zone("Living Room", symbol: "sofa.fill"),
            zone("Kitchen", symbol: "fork.knife"),
            zone("Bedroom", symbol: "bed.double.fill"),
            zone("Office", symbol: "desktopcomputer"),
            zone("Patio", symbol: "tree.fill"),
        ].compactMap({ $0 }) {
            zoneStore.add(seeded)
        }

        // A cross-room "Party Floor" zone showing off multi-zone gradients.
        let partyLights = (byRoom["Living Room"] ?? []) + (byRoom["Kitchen"] ?? [])
        if !partyLights.isEmpty {
            zoneStore.add(
                Zone(name: "Party Floor", symbolName: "party.popper.fill", lightIDs: partyLights.map(\.id))
            )
        }
        lightsStore.reconcile()
    }
}
