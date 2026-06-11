import Foundation
import Observation

/// The app-wide source of truth: merges lights from every connected provider,
/// dedupes bulbs that show up twice (Hue bridged through Home Assistant), applies
/// optimistic updates, and fans zone commands out per provider.
@MainActor
@Observable
public final class LightsStore {
    public private(set) var lights: [Light] = []
    public private(set) var connectionStates: [ProviderID: ProviderConnectionState] = [:]
    public private(set) var nativeGroups: [ProviderID: [ProviderGroup]] = [:]
    public var dedupeOverrides: DedupeOverrides {
        didSet { sync.save(dedupeOverrides, forKey: SyncEngine.Keys.dedupeOverrides) }
    }
    public var lastError: String?

    public let zoneStore: ZoneStore
    private var providers: [ProviderID: any LightProvider] = [:]
    private var eventTasks: [ProviderID: Task<Void, Never>] = [:]
    private let sync: SyncEngine
    /// Called after every reconcile so the app can refresh widget snapshots.
    public var onReconcile: (@MainActor () -> Void)?

    public init(zoneStore: ZoneStore, sync: SyncEngine = .shared) {
        self.zoneStore = zoneStore
        self.sync = sync
        self.dedupeOverrides = sync.load(DedupeOverrides.self, forKey: SyncEngine.Keys.dedupeOverrides) ?? DedupeOverrides()
    }

    // MARK: Providers

    public var connectedProviders: [ProviderID] { Array(providers.keys) }

    public func register(_ provider: any LightProvider) async {
        let id = provider.id
        providers[id] = provider
        connectionStates[id] = .connecting

        eventTasks[id]?.cancel()
        eventTasks[id] = Task { [weak self] in
            let stream = await provider.events()
            for await event in stream {
                guard let self else { return }
                await self.handle(event, from: id)
            }
        }

        do {
            try await provider.connect()
            connectionStates[id] = .connected
            await refresh(provider: id)
        } catch {
            connectionStates[id] = .failed(error.localizedDescription)
        }
    }

    public func remove(providerID: ProviderID) async {
        if let provider = providers.removeValue(forKey: providerID) {
            await provider.disconnect()
        }
        eventTasks.removeValue(forKey: providerID)?.cancel()
        connectionStates[providerID] = nil
        nativeGroups[providerID] = nil
        lights.removeAll { $0.id.provider == providerID }
        reconcile()
    }

    public func refresh() async {
        for id in providers.keys {
            await refresh(provider: id)
        }
    }

    private func refresh(provider id: ProviderID) async {
        guard let provider = providers[id] else { return }
        do {
            let fetched = try await provider.lights()
            let groups = try await provider.nativeGroups()
            lights.removeAll { $0.id.provider == id }
            lights.append(contentsOf: fetched)
            nativeGroups[id] = groups
            sortLights()
            reconcile()
        } catch {
            lastError = "\(id.displayName): \(error.localizedDescription)"
        }
    }

    private func handle(_ event: ProviderEvent, from id: ProviderID) {
        switch event {
        case .lightsReplaced(let fetched):
            lights.removeAll { $0.id.provider == id }
            lights.append(contentsOf: fetched)
            sortLights()
            reconcile()
        case .lightUpdated(let light):
            if let index = lights.firstIndex(where: { $0.id == light.id }) {
                lights[index] = light
            } else {
                lights.append(light)
                sortLights()
            }
            reconcile()
        case .connectionChanged(let state):
            connectionStates[id] = state
        }
    }

    private func sortLights() {
        lights.sort {
            ($0.room ?? "~", $0.name, $0.id.raw) < ($1.room ?? "~", $1.name, $1.id.raw)
        }
    }

    // MARK: Dedupe

    /// IDs of lights hidden because the same bulb is already shown via a direct
    /// integration (e.g. a Hue light that HA re-exposes).
    public var suppressedLightIDs: Set<LightID> {
        var suppressed = Set<LightID>()

        let directHueIDs = Set(
            lights
                .filter { if case .hue = $0.id.provider { return true } else { return false } }
                .map { $0.id.raw.lowercased() }
        )

        if !directHueIDs.isEmpty {
            for light in lights where light.id.provider == .homeAssistant {
                guard light.dedupeHints.sourcePlatform == "hue",
                      let uniqueID = light.dedupeHints.uniqueID?.lowercased() else { continue }
                if directHueIDs.contains(uniqueID) {
                    suppressed.insert(light.id)
                }
            }
        }

        suppressed.subtract(dedupeOverrides.alwaysShow)
        suppressed.formUnion(dedupeOverrides.alwaysHide)
        return suppressed
    }

    public var visibleLights: [Light] {
        let suppressed = suppressedLightIDs
        return lights.filter { !suppressed.contains($0.id) }
    }

    /// HA lights currently auto-hidden — surfaced in Settings so the user can override.
    public var autoSuppressedLights: [Light] {
        let suppressed = suppressedLightIDs.subtracting(dedupeOverrides.alwaysHide)
        return lights.filter { suppressed.contains($0.id) }
    }

    // MARK: Zones

    public var allLightsZone: Zone {
        Zone.allLights(with: visibleLights.map(\.id))
    }

    /// User zones plus the implicit whole-house zone, always first.
    public var displayZones: [Zone] {
        [allLightsZone] + zoneStore.zones
    }

    public func zone(withID id: UUID) -> Zone? {
        displayZones.first { $0.id == id }
    }

    public func lights(in zone: Zone) -> [Light] {
        let byID = Dictionary(uniqueKeysWithValues: lights.map { ($0.id, $0) })
        return zone.lightIDs.compactMap { byID[$0] }
    }

    public func onCount(in zone: Zone) -> Int {
        lights(in: zone).filter(\.state.isOn).count
    }

    // MARK: Commands

    public func setPower(_ on: Bool, lightIDs: [LightID]) async {
        applyOptimistic(lightIDs) { $0.state.isOn = on }
        await perProvider(lightIDs) { provider, ids in
            try await provider.setPower(on, lights: ids)
        }
    }

    public func toggle(zone: Zone) async {
        let target = onCount(in: zone) == 0
        await setPower(target, lightIDs: zone.lightIDs)
    }

    public func setBrightness(_ value: Double, lightIDs: [LightID]) async {
        applyOptimistic(lightIDs) {
            $0.state.brightness = value
            if value > 0 { $0.state.isOn = true }
        }
        await perProvider(lightIDs) { provider, ids in
            try await provider.setBrightness(value, lights: ids)
        }
    }

    public func setColor(_ color: PHColor, lightIDs: [LightID]) async {
        applyOptimistic(lightIDs) {
            guard $0.capabilities.contains(.color) else { return }
            $0.state.color = color
            $0.state.mirek = nil
            $0.state.isOn = true
        }
        await perProvider(lightIDs) { provider, ids in
            try await provider.setColor(color, lights: ids)
        }
    }

    /// Sweeps a palette across the zone's lights (in zone order). Native gradient
    /// strips receive a multi-point slice; white-only lights are skipped.
    public func applyPalette(_ palette: Palette, to zone: Zone) async {
        let zoneLights = lights(in: zone)
        let colorCapable = zoneLights.filter { $0.capabilities.contains(.color) }
        let assignments = GradientEngine.assignments(palette: palette, lights: colorCapable)

        applyOptimistic(colorCapable.map(\.id)) { light in
            switch assignments[light.id] {
            case .solid(let color):
                light.state.color = color
                light.state.isOn = true
            case .nativeGradient(let points):
                light.state.color = points.first
                light.state.isOn = true
            case nil:
                break
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for light in colorCapable {
                guard let assignment = assignments[light.id],
                      let provider = providers[light.id.provider] else { continue }
                group.addTask { [weak self] in
                    do {
                        switch assignment {
                        case .solid(let color):
                            try await provider.setColor(color, lights: [light.id])
                        case .nativeGradient(let points):
                            try await provider.applyNativeGradient(points, to: light.id)
                        }
                    } catch {
                        await self?.report(error: error, provider: light.id.provider)
                    }
                }
            }
        }
        reconcile()
    }

    private func report(error: Error, provider: ProviderID) {
        lastError = "\(provider.displayName): \(error.localizedDescription)"
    }

    /// Test seam: inject lights directly without a provider (no snapshot writes).
    func setLightsForTesting(_ newLights: [Light]) {
        lights = newLights
        sortLights()
    }

    private func applyOptimistic(_ ids: [LightID], _ change: (inout Light) -> Void) {
        let idSet = Set(ids)
        for index in lights.indices where idSet.contains(lights[index].id) {
            change(&lights[index])
        }
        reconcile()
    }

    private func perProvider(
        _ ids: [LightID],
        _ operation: @escaping (any LightProvider, [LightID]) async throws -> Void
    ) async {
        let grouped = Dictionary(grouping: ids) { $0.provider }
        await withTaskGroup(of: Void.self) { group in
            for (providerID, providerIDs) in grouped {
                guard let provider = providers[providerID] else { continue }
                group.addTask { [weak self] in
                    do {
                        try await operation(provider, providerIDs)
                    } catch {
                        await self?.report(error: error, provider: providerID)
                    }
                }
            }
        }
    }

    // MARK: Widget snapshot

    /// Recomputes the widget-facing snapshot and light cache. Called after state
    /// changes; cheap enough to run every time.
    public func reconcile() {
        let visible = visibleLights
        let zoneSummaries = displayZones.map { zone -> WidgetSnapshot.ZoneSummary in
            let members = lights(in: zone)
            let accents = members
                .filter(\.state.isOn)
                .prefix(4)
                .map { $0.state.displayColor.hexString }
            return WidgetSnapshot.ZoneSummary(
                id: zone.id,
                name: zone.name,
                symbolName: zone.symbolName,
                lightCount: members.count,
                onCount: members.filter(\.state.isOn).count,
                accentHexColors: Array(accents)
            )
        }

        let customPalettes = sync.load([Palette].self, forKey: SyncEngine.Keys.customPalettes) ?? []
        let paletteSummaries = (Palette.builtIns + customPalettes).map {
            WidgetSnapshot.PaletteSummary(
                id: $0.id,
                name: $0.name,
                hexColors: $0.stops.map(\.color.hexString)
            )
        }

        AppGroupSnapshotStore.write(
            WidgetSnapshot(
                zones: zoneSummaries,
                palettes: paletteSummaries,
                totalLightsOn: visible.filter(\.state.isOn).count,
                updatedAt: Date()
            )
        )
        LightCacheStore.write(visible)
        onReconcile?()
    }
}

/// Cached visible lights (with capabilities) so widget intents can act without a
/// running app or live provider connection.
public enum LightCacheStore {
    static let key = "cache.lights.v1"

    public static func write(_ lights: [Light]) {
        SyncEngine.shared.save(lights, forKey: key, synced: false)
    }

    public static func read() -> [Light] {
        SyncEngine.shared.load([Light].self, forKey: key, synced: false) ?? []
    }
}
