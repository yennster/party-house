import Foundation

/// A compact, widget-readable snapshot of app state, written to the shared App Group
/// whenever the store reconciles. Widgets render from this; intents act on it.
public struct WidgetSnapshot: Codable, Sendable {
    public struct ZoneSummary: Codable, Identifiable, Sendable {
        public var id: UUID
        public var name: String
        public var symbolName: String
        public var lightCount: Int
        public var onCount: Int
        /// Representative colors of the lights that are on, for tinting.
        public var accentHexColors: [String]

        public init(id: UUID, name: String, symbolName: String, lightCount: Int, onCount: Int, accentHexColors: [String]) {
            self.id = id
            self.name = name
            self.symbolName = symbolName
            self.lightCount = lightCount
            self.onCount = onCount
            self.accentHexColors = accentHexColors
        }
    }

    public struct PaletteSummary: Codable, Identifiable, Sendable {
        public var id: UUID
        public var name: String
        public var hexColors: [String]

        public init(id: UUID, name: String, hexColors: [String]) {
            self.id = id
            self.name = name
            self.hexColors = hexColors
        }
    }

    public var zones: [ZoneSummary]
    public var palettes: [PaletteSummary]
    public var totalLightsOn: Int
    public var updatedAt: Date

    public init(zones: [ZoneSummary], palettes: [PaletteSummary], totalLightsOn: Int, updatedAt: Date) {
        self.zones = zones
        self.palettes = palettes
        self.totalLightsOn = totalLightsOn
        self.updatedAt = updatedAt
    }
}

public enum AppGroupSnapshotStore {
    static let snapshotKey = "widget.snapshot.v1"

    public static func write(_ snapshot: WidgetSnapshot) {
        SyncEngine.shared.save(snapshot, forKey: snapshotKey, synced: false)
    }

    public static func read() -> WidgetSnapshot? {
        SyncEngine.shared.load(WidgetSnapshot.self, forKey: snapshotKey, synced: false)
    }
}
