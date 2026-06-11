import Foundation

/// A fully local fake house used for development, previews, UI tests, and App Store
/// screenshots (`-Demo YES`). Commands mutate in-memory state and emit events just
/// like a real provider.
public actor DemoProvider: LightProvider {
    public nonisolated let id: ProviderID = .demo
    public nonisolated let displayName = "Demo House"

    private var lightsByID: [LightID: Light]
    private var order: [LightID]
    private let groups: [ProviderGroup]
    private var continuations: [UUID: AsyncStream<ProviderEvent>.Continuation] = [:]

    public init() {
        let seeded = DemoProvider.seedLights()
        self.lightsByID = Dictionary(uniqueKeysWithValues: seeded.map { ($0.id, $0) })
        self.order = seeded.map(\.id)
        self.groups = DemoProvider.seedGroups(from: seeded)
    }

    // MARK: LightProvider

    public func connect() async throws {
        broadcast(.connectionChanged(.connected))
    }

    public func disconnect() async {
        broadcast(.connectionChanged(.disconnected))
    }

    public func lights() async throws -> [Light] {
        order.compactMap { lightsByID[$0] }
    }

    public func nativeGroups() async throws -> [ProviderGroup] {
        groups
    }

    public func setPower(_ on: Bool, lights ids: [LightID]) async throws {
        mutate(ids) { $0.state.isOn = on }
    }

    public func setBrightness(_ value: Double, lights ids: [LightID]) async throws {
        mutate(ids) {
            $0.state.brightness = min(max(value, 0), 1)
            if value > 0 { $0.state.isOn = true }
        }
    }

    public func setColor(_ color: PHColor, lights ids: [LightID]) async throws {
        mutate(ids) {
            guard $0.capabilities.contains(.color) else { return }
            $0.state.color = color
            $0.state.mirek = nil
            $0.state.isOn = true
        }
    }

    public func applyNativeGradient(_ points: [PHColor], to light: LightID) async throws {
        mutate([light]) {
            $0.state.color = points.first
            $0.state.isOn = true
        }
    }

    public func events() async -> AsyncStream<ProviderEvent> {
        let key = UUID()
        return AsyncStream { continuation in
            continuations[key] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(key) }
            }
        }
    }

    // MARK: Internals

    private func removeContinuation(_ key: UUID) {
        continuations[key] = nil
    }

    private func mutate(_ ids: [LightID], _ change: (inout Light) -> Void) {
        for id in ids {
            guard var light = lightsByID[id] else { continue }
            change(&light)
            lightsByID[id] = light
            broadcast(.lightUpdated(light))
        }
    }

    private func broadcast(_ event: ProviderEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    // MARK: Seed data

    private static func light(
        _ key: String,
        _ name: String,
        room: String,
        caps: LightCapabilities,
        on: Bool,
        brightness: Double = 0.8,
        hex: String? = nil,
        mirek: Int? = nil
    ) -> Light {
        Light(
            id: LightID(provider: .demo, raw: key),
            name: name,
            room: room,
            capabilities: caps,
            state: LightState(
                isOn: on,
                brightness: brightness,
                color: hex.flatMap(PHColor.init(hex:)),
                mirek: mirek
            )
        )
    }

    static func seedLights() -> [Light] {
        let color: LightCapabilities = [.power, .dimming, .color, .colorTemperature]
        let strip: LightCapabilities = [.power, .dimming, .color, .colorTemperature, .nativeGradient]
        let white: LightCapabilities = [.power, .dimming, .colorTemperature]

        return [
            light("living-couch-left", "Couch Lamp Left", room: "Living Room", caps: color, on: true, brightness: 0.7, hex: "#ff2e93"),
            light("living-couch-right", "Couch Lamp Right", room: "Living Room", caps: color, on: true, brightness: 0.7, hex: "#a23ad6"),
            light("living-tv-strip", "TV Gradient Strip", room: "Living Room", caps: strip, on: true, brightness: 0.9, hex: "#3f37c9"),
            light("living-ceiling", "Ceiling Wash", room: "Living Room", caps: color, on: true, brightness: 0.55, hex: "#ff6b35"),
            light("kitchen-island-1", "Island Pendant 1", room: "Kitchen", caps: color, on: true, brightness: 0.85, hex: "#00bbf9"),
            light("kitchen-island-2", "Island Pendant 2", room: "Kitchen", caps: color, on: true, brightness: 0.85, hex: "#00f5d4"),
            light("kitchen-cabinet", "Under-Cabinet Strip", room: "Kitchen", caps: strip, on: false, brightness: 0.6, hex: "#9b5de5"),
            light("bedroom-night-left", "Nightstand Left", room: "Bedroom", caps: color, on: false, brightness: 0.3, mirek: 400),
            light("bedroom-night-right", "Nightstand Right", room: "Bedroom", caps: color, on: false, brightness: 0.3, mirek: 400),
            light("bedroom-ceiling", "Bedroom Ceiling", room: "Bedroom", caps: white, on: false, brightness: 0.5, mirek: 366),
            light("office-desk", "Desk Lamp", room: "Office", caps: color, on: true, brightness: 1.0, hex: "#16c7b2"),
            light("office-shelf", "Shelf Strip", room: "Office", caps: strip, on: true, brightness: 0.75, hex: "#7b2cbf"),
            light("hallway", "Hallway Sconce", room: "Hallway", caps: white, on: true, brightness: 0.4, mirek: 320),
            light("patio-string", "String Lights", room: "Patio", caps: color, on: true, brightness: 0.65, hex: "#ffd166"),
            light("patio-flood", "Patio Flood", room: "Patio", caps: color, on: false, brightness: 0.8, hex: "#90e0ef"),
        ]
    }

    static func seedGroups(from lights: [Light]) -> [ProviderGroup] {
        let rooms = Dictionary(grouping: lights) { $0.room ?? "Other" }
        return rooms
            .map { name, members in
                ProviderGroup(id: "demo-room-\(name)", name: name, lightIDs: members.map(\.id))
            }
            .sorted { $0.name < $1.name }
    }
}
