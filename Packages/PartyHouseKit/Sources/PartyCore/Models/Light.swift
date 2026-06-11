import Foundation

/// Identifies a connected integration. Multiple Hue bridges are supported via the
/// associated bridge id.
public enum ProviderID: Hashable, Codable, Sendable, CustomStringConvertible {
    case hue(bridgeID: String)
    case homeAssistant
    case lifx
    case demo

    public var description: String {
        switch self {
        case .hue(let bridgeID): return "hue:\(bridgeID)"
        case .homeAssistant: return "homeassistant"
        case .lifx: return "lifx"
        case .demo: return "demo"
        }
    }

    public var displayName: String {
        switch self {
        case .hue: return "Philips Hue"
        case .homeAssistant: return "Home Assistant"
        case .lifx: return "LIFX"
        case .demo: return "Demo House"
        }
    }
}

/// Globally unique light identity: the owning provider plus the provider's own id
/// (Hue v2 UUID, HA entity_id, LIFX serial).
public struct LightID: Hashable, Codable, Sendable {
    public let provider: ProviderID
    public let raw: String

    public init(provider: ProviderID, raw: String) {
        self.provider = provider
        self.raw = raw
    }
}

public struct LightCapabilities: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let power = LightCapabilities(rawValue: 1 << 0)
    public static let dimming = LightCapabilities(rawValue: 1 << 1)
    public static let color = LightCapabilities(rawValue: 1 << 2)
    public static let colorTemperature = LightCapabilities(rawValue: 1 << 3)
    /// The light is a gradient strip that natively renders multiple colors at once.
    public static let nativeGradient = LightCapabilities(rawValue: 1 << 4)
}

public struct LightState: Hashable, Codable, Sendable {
    public var isOn: Bool
    /// 0...1
    public var brightness: Double
    public var color: PHColor?
    /// Color temperature in mirek, when the light is in CT mode.
    public var mirek: Int?
    public var isReachable: Bool

    public init(
        isOn: Bool = false,
        brightness: Double = 1,
        color: PHColor? = nil,
        mirek: Int? = nil,
        isReachable: Bool = true
    ) {
        self.isOn = isOn
        self.brightness = brightness
        self.color = color
        self.mirek = mirek
        self.isReachable = isReachable
    }

    /// Best-effort sRGB color for previews, whatever mode the light is in.
    public var displayColor: PHColor {
        if let color { return color }
        if let mirek { return ColorMath.color(fromMirek: mirek) }
        return .warmWhite
    }
}

/// Hints used to recognize the same physical bulb exposed by two providers at once
/// (e.g. a Hue light that Home Assistant also bridges).
public struct DedupeHints: Hashable, Codable, Sendable {
    /// HA entity registry unique_id, or the provider-native unique id.
    public var uniqueID: String?
    /// The upstream platform that produced the entity ("hue", "lifx", ...) when known.
    public var sourcePlatform: String?

    public init(uniqueID: String? = nil, sourcePlatform: String? = nil) {
        self.uniqueID = uniqueID
        self.sourcePlatform = sourcePlatform
    }
}

public struct Light: Identifiable, Hashable, Codable, Sendable {
    public let id: LightID
    public var name: String
    /// Provider-native room/area name; used to seed zone suggestions and sorting.
    public var room: String?
    public var capabilities: LightCapabilities
    public var state: LightState
    public var dedupeHints: DedupeHints

    public init(
        id: LightID,
        name: String,
        room: String? = nil,
        capabilities: LightCapabilities,
        state: LightState = LightState(),
        dedupeHints: DedupeHints = DedupeHints()
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.capabilities = capabilities
        self.state = state
        self.dedupeHints = dedupeHints
    }
}

/// A provider-native grouping (Hue room/zone, Home Assistant area). Used to suggest
/// app zones and to enable native group commands.
public struct ProviderGroup: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var name: String
    public var lightIDs: [LightID]

    public init(id: String, name: String, lightIDs: [LightID]) {
        self.id = id
        self.name = name
        self.lightIDs = lightIDs
    }
}
