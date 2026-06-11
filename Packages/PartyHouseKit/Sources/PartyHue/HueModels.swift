import Foundation
import PartyCore

// MARK: - CLIP v2 envelope

struct HueEnvelope<T: Decodable>: Decodable {
    struct APIError: Decodable {
        let description: String
    }

    let errors: [APIError]
    let data: [T]
}

struct HueResourceRef: Decodable, Hashable {
    let rid: String
    let rtype: String
}

struct HueMetadata: Decodable {
    let name: String?
    let archetype: String?
}

// MARK: - Light

struct HueLightResource: Decodable {
    struct OnState: Decodable {
        let on: Bool
    }

    struct Dimming: Decodable {
        let brightness: Double // 0...100
    }

    struct ColorState: Decodable {
        struct XY: Decodable {
            let x: Double
            let y: Double
        }

        let xy: XY?
    }

    struct ColorTemperature: Decodable {
        let mirek: Int?
    }

    struct Gradient: Decodable {
        let points: [GradientPoint]
        let pointsCapable: Int?

        enum CodingKeys: String, CodingKey {
            case points
            case pointsCapable = "points_capable"
        }
    }

    /// Gradient points arrive as `{"color": {"xy": {...}}}`, but some firmware
    /// emits the xy object directly — accept both shapes.
    struct GradientPoint: Decodable {
        let xy: ColorState.XY?

        enum CodingKeys: String, CodingKey {
            case color
            case xy
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let color = try container.decodeIfPresent(ColorState.self, forKey: .color) {
                xy = color.xy
            } else {
                xy = try container.decodeIfPresent(ColorState.XY.self, forKey: .xy)
            }
        }
    }

    let id: String
    let owner: HueResourceRef?
    let metadata: HueMetadata?
    let on: OnState?
    let dimming: Dimming?
    let color: ColorState?
    let colorTemperature: ColorTemperature?
    let gradient: Gradient?

    enum CodingKeys: String, CodingKey {
        case id, owner, metadata, on, dimming, color, gradient
        case colorTemperature = "color_temperature"
    }
}

// MARK: - Groups & devices

struct HueGroupResource: Decodable {
    let id: String
    let metadata: HueMetadata?
    /// Rooms reference devices; zones reference lights directly.
    let children: [HueResourceRef]
    /// Contains the grouped_light service for native group commands.
    let services: [HueResourceRef]?

    var groupedLightID: String? {
        services?.first { $0.rtype == "grouped_light" }?.rid
    }
}

struct HueDeviceResource: Decodable {
    let id: String
    let metadata: HueMetadata?
    let services: [HueResourceRef]

    var lightServiceIDs: [String] {
        services.filter { $0.rtype == "light" }.map(\.rid)
    }
}

// MARK: - Events (SSE)

struct HueEvent: Decodable {
    let type: String // "update", "add", "delete"
    let data: [HueEventData]
}

/// A partial resource in an SSE frame. Only fields present in the update are set.
struct HueEventData: Decodable {
    let id: String
    let type: String
    let on: HueLightResource.OnState?
    let dimming: HueLightResource.Dimming?
    let color: HueLightResource.ColorState?
    let colorTemperature: HueLightResource.ColorTemperature?

    enum CodingKeys: String, CodingKey {
        case id, type, on, dimming, color
        case colorTemperature = "color_temperature"
    }
}

// MARK: - Discovery / config

/// Response of the unauthenticated `GET /api/0/config` endpoint.
struct HueBridgeInfo: Decodable {
    let name: String?
    let bridgeid: String?
    let modelid: String?
}

// MARK: - Payload builders

enum HuePayloads {
    static func power(_ on: Bool) -> [String: Any] {
        ["on": ["on": on]]
    }

    static func brightness(_ value: Double) -> [String: Any] {
        [
            "on": ["on": value > 0],
            "dimming": ["brightness": min(max(value, 0), 1) * 100.0],
        ]
    }

    static func color(_ color: PHColor) -> [String: Any] {
        let (xy, luminance) = ColorMath.xy(from: color)
        return [
            "on": ["on": true],
            "color": ["xy": ["x": xy.x, "y": xy.y]],
            "dimming": ["brightness": max(luminance, 0.05) * 100.0],
        ]
    }

    /// Hue gradient strips accept 2...5 points.
    static func gradient(_ points: [PHColor]) -> [String: Any] {
        let clamped = Array(points.prefix(5))
        let payloadPoints = clamped.map { point -> [String: Any] in
            let (xy, _) = ColorMath.xy(from: point)
            return ["color": ["xy": ["x": xy.x, "y": xy.y]]]
        }
        return [
            "on": ["on": true],
            "gradient": ["points": payloadPoints],
        ]
    }
}
