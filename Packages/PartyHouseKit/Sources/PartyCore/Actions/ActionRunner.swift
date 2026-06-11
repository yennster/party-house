import Foundation

/// Stateless command executor used by widget App Intents. It rebuilds just enough
/// context from the App Group cache + keychain to fire one-shot calls at Hue and
/// Home Assistant without spinning up live provider connections.
///
/// LIFX lights are skipped here (the LAN client needs a discovery pass that is too
/// heavy for a widget process); the app handles them when it next launches.
public struct ActionRunner: Sendable {
    private let configs: ProviderConfigs

    public init(configs: ProviderConfigs = ProviderConfigs.load()) {
        self.configs = configs
    }

    public func zone(withID id: UUID) -> Zone? {
        if id == Zone.allLightsID {
            return Zone.allLights(with: LightCacheStore.read().map(\.id))
        }
        let zones = SyncEngine.shared.load([Zone].self, forKey: SyncEngine.Keys.zones) ?? []
        return zones.first { $0.id == id }
    }

    public func palette(withID id: UUID) -> Palette? {
        let custom = SyncEngine.shared.load([Palette].self, forKey: SyncEngine.Keys.customPalettes) ?? []
        return (Palette.builtIns + custom).first { $0.id == id }
    }

    /// Toggles a zone based on the cached on-count: any light on -> all off.
    public func toggleZone(_ zoneID: UUID) async throws {
        guard let zone = zone(withID: zoneID) else { throw ProviderError("Zone not found.") }
        let cached = LightCacheStore.read().filter { zone.lightIDs.contains($0.id) }
        let anyOn = cached.contains(where: \.state.isOn)
        try await setPower(!anyOn, zone: zone)
    }

    public func setPower(_ on: Bool, zone: Zone) async throws {
        let grouped = Dictionary(grouping: zone.lightIDs) { $0.provider }
        var firstError: Error?

        for (providerID, ids) in grouped {
            do {
                switch providerID {
                case .hue(let bridgeID):
                    guard let bridge = configs.hueBridges.first(where: { $0.bridgeID == bridgeID }),
                          let appKey = KeychainStore.read(.hueApplicationKey, account: bridgeID) else { continue }
                    let client = HueActionClient(host: bridge.host, applicationKey: appKey)
                    try await client.setPower(on, lightIDs: ids.map(\.raw))
                case .homeAssistant:
                    let client = try makeHAClient()
                    try await client.setPower(on, entityIDs: ids.map(\.raw))
                case .lifx, .demo:
                    continue
                }
            } catch {
                firstError = firstError ?? error
            }
        }

        updateCachedPower(on, for: zone.lightIDs)
        if let firstError { throw firstError }
    }

    public func applyPalette(_ paletteID: UUID, zoneID: UUID) async throws {
        guard let zone = zone(withID: zoneID) else { throw ProviderError("Zone not found.") }
        guard let palette = palette(withID: paletteID) else { throw ProviderError("Palette not found.") }

        let byID = Dictionary(uniqueKeysWithValues: LightCacheStore.read().map { ($0.id, $0) })
        let zoneLights = zone.lightIDs.compactMap { byID[$0] }.filter { $0.capabilities.contains(.color) }
        let assignments = GradientEngine.assignments(palette: palette, lights: zoneLights)

        var firstError: Error?
        for light in zoneLights {
            guard let assignment = assignments[light.id] else { continue }
            do {
                switch light.id.provider {
                case .hue(let bridgeID):
                    guard let bridge = configs.hueBridges.first(where: { $0.bridgeID == bridgeID }),
                          let appKey = KeychainStore.read(.hueApplicationKey, account: bridgeID) else { continue }
                    let client = HueActionClient(host: bridge.host, applicationKey: appKey)
                    switch assignment {
                    case .solid(let color):
                        try await client.setColor(color, lightID: light.id.raw)
                    case .nativeGradient(let points):
                        try await client.setGradient(points, lightID: light.id.raw)
                    }
                case .homeAssistant:
                    let client = try makeHAClient()
                    if case .solid(let color) = assignment {
                        try await client.setColor(color, entityIDs: [light.id.raw])
                    } else if case .nativeGradient(let points) = assignment, let first = points.first {
                        try await client.setColor(first, entityIDs: [light.id.raw])
                    }
                case .lifx, .demo:
                    continue
                }
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }

    private func makeHAClient() throws -> HAActionClient {
        guard let config = configs.homeAssistant,
              let token = KeychainStore.read(.homeAssistantToken) else {
            throw ProviderError("Home Assistant is not configured.")
        }
        return HAActionClient(urls: config.urls, token: token)
    }

    private func updateCachedPower(_ on: Bool, for ids: [LightID]) {
        var cached = LightCacheStore.read()
        let idSet = Set(ids)
        for index in cached.indices where idSet.contains(cached[index].id) {
            cached[index].state.isOn = on
        }
        LightCacheStore.write(cached)
    }
}
