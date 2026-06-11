import Foundation
import Observation

/// Per-light dedupe decisions the user made by hand, overriding the automatic
/// Hue-via-Home-Assistant suppression.
public struct DedupeOverrides: Codable, Sendable, Equatable {
    public var alwaysShow: Set<LightID>
    public var alwaysHide: Set<LightID>

    public init(alwaysShow: Set<LightID> = [], alwaysHide: Set<LightID> = []) {
        self.alwaysShow = alwaysShow
        self.alwaysHide = alwaysHide
    }
}

@MainActor
@Observable
public final class ZoneStore {
    public private(set) var zones: [Zone] = []

    private let sync: SyncEngine

    public init(sync: SyncEngine = .shared) {
        self.sync = sync
        zones = sync.load([Zone].self, forKey: SyncEngine.Keys.zones) ?? []
        sync.observeExternalChanges { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.zones = self.sync.load([Zone].self, forKey: SyncEngine.Keys.zones) ?? self.zones
            }
        }
    }

    public func add(_ zone: Zone) {
        zones.append(zone)
        persist()
    }

    public func update(_ zone: Zone) {
        guard let index = zones.firstIndex(where: { $0.id == zone.id }) else { return }
        zones[index] = zone
        persist()
    }

    public func delete(_ zoneID: UUID) {
        zones.removeAll { $0.id == zoneID }
        persist()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var copy = zones
        let moved = source.sorted(by: >).map { copy.remove(at: $0) }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        copy.insert(contentsOf: moved.reversed(), at: max(adjustedDestination, 0))
        zones = copy
        persist()
    }

    /// Creates an app zone mirroring a provider-native group (Hue room/zone, HA area).
    public func importNativeGroup(_ group: ProviderGroup) {
        guard !zones.contains(where: { $0.name.caseInsensitiveCompare(group.name) == .orderedSame }) else { return }
        add(Zone(name: group.name, lightIDs: group.lightIDs))
    }

    /// Drops references to lights that no longer exist (e.g. removed from the bridge).
    public func prune(existing lightIDs: Set<LightID>) {
        var changed = false
        for index in zones.indices {
            let filtered = zones[index].lightIDs.filter { lightIDs.contains($0) }
            if filtered.count != zones[index].lightIDs.count {
                zones[index].lightIDs = filtered
                changed = true
            }
        }
        if changed { persist() }
    }

    private func persist() {
        sync.save(zones, forKey: SyncEngine.Keys.zones)
    }
}
