import Foundation

/// A user-defined group of lights that can span providers — a Hue bulb, an HA entity,
/// and a LIFX strip can all live in one zone. Light order matters: gradients sweep
/// across the zone in this order.
public struct Zone: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    /// SF Symbol name shown on zone cards and widgets.
    public var symbolName: String
    public var lightIDs: [LightID]

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "lamp.ceiling.inverse",
        lightIDs: [LightID] = []
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.lightIDs = lightIDs
    }
}

public extension Zone {
    /// Stable identifier used for the implicit whole-house zone in widgets/intents.
    static let allLightsID = UUID(uuidString: "00000000-0000-0000-0000-00000000A11A")!

    static func allLights(with lightIDs: [LightID]) -> Zone {
        Zone(id: allLightsID, name: "All Lights", symbolName: "house.fill", lightIDs: lightIDs)
    }

    var isAllLights: Bool { id == Zone.allLightsID }
}
