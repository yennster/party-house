import AppIntents
import Foundation
import PartyCore

/// A Party House zone, exposed to widgets, Siri, Shortcuts, and Spotlight.
struct ZoneEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Zone"
    static let defaultQuery = ZoneEntityQuery()

    let id: UUID
    let name: String
    let symbolName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbolName))
    }

    static func all() -> [ZoneEntity] {
        let snapshot = AppGroupSnapshotStore.read()
        if let snapshot, !snapshot.zones.isEmpty {
            return snapshot.zones.map {
                ZoneEntity(id: $0.id, name: $0.name, symbolName: $0.symbolName)
            }
        }
        // Cold start before the app ever wrote a snapshot: zones from synced config.
        let zones = SyncEngine.shared.load([Zone].self, forKey: SyncEngine.Keys.zones) ?? []
        return [ZoneEntity(id: Zone.allLightsID, name: "All Lights", symbolName: "house.fill")]
            + zones.map { ZoneEntity(id: $0.id, name: $0.name, symbolName: $0.symbolName) }
    }
}

struct ZoneEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ZoneEntity] {
        ZoneEntity.all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ZoneEntity] {
        ZoneEntity.all()
    }

    func defaultResult() async -> ZoneEntity? {
        ZoneEntity.all().first
    }
}

/// A gradient palette (built-in or custom), for the palette quick-apply widget.
struct PaletteEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Gradient"
    static let defaultQuery = PaletteEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static func all() -> [PaletteEntity] {
        let custom = SyncEngine.shared.load([Palette].self, forKey: SyncEngine.Keys.customPalettes) ?? []
        return (Palette.builtIns + custom).map { PaletteEntity(id: $0.id, name: $0.name) }
    }
}

struct PaletteEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [PaletteEntity] {
        PaletteEntity.all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PaletteEntity] {
        PaletteEntity.all()
    }

    func defaultResult() async -> PaletteEntity? {
        PaletteEntity.all().first
    }
}
