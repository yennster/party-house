import Foundation
import HAKit
import PartyCore

/// Home Assistant integration over HAKit's WebSocket API. Lights are read from the
/// states cache (live-updating), areas come from the registries, and commands are
/// `light.turn_on` / `light.turn_off` service calls.
///
/// Anything Home Assistant can switch — Tuya, Govee, WiZ, Zigbee, Matter — shows up
/// here, which is how Party House supports brands without native integrations.
public actor HAProvider: LightProvider {
    public nonisolated let id: ProviderID = .homeAssistant
    public nonisolated let displayName = "Home Assistant"

    private let config: HomeAssistantConfig
    private let token: String

    private var connection: HAConnection?
    private var statesCancellable: HACancellable?
    private var lightsByID: [String: Light] = [:]
    private var registry = HARegistrySnapshot()
    private var continuations: [UUID: AsyncStream<ProviderEvent>.Continuation] = [:]

    public init(config: HomeAssistantConfig, token: String) {
        self.config = config
        self.token = token
    }

    // MARK: LightProvider

    public func connect() async throws {
        broadcast(.connectionChanged(.connecting))

        guard let url = await HAURLSelector.pickReachableURL(from: config.urls, token: token) else {
            let message = "Home Assistant is unreachable. Check the internal/external URLs in Settings."
            broadcast(.connectionChanged(.failed(message)))
            throw ProviderError(message)
        }

        let token = self.token
        let configuration = HAConnectionConfiguration(
            connectionInfo: { try? HAConnectionInfo(url: url) },
            fetchAuthToken: { completion in completion(.success(token)) }
        )
        let connection = HAKit.connection(configuration: configuration, connectAutomatically: true)
        self.connection = connection

        registry = await HARegistrySnapshot.fetch(connection: connection)
        subscribeToStates(connection)
        broadcast(.connectionChanged(.connected))
    }

    public func disconnect() async {
        statesCancellable?.cancel()
        statesCancellable = nil
        connection?.disconnect()
        connection = nil
        broadcast(.connectionChanged(.disconnected))
    }

    public func lights() async throws -> [Light] {
        Array(lightsByID.values)
    }

    public func nativeGroups() async throws -> [ProviderGroup] {
        var byArea: [String: [LightID]] = [:]
        for light in lightsByID.values {
            guard let room = light.room else { continue }
            byArea[room, default: []].append(light.id)
        }
        return byArea
            .map { name, ids in
                ProviderGroup(id: "ha-area-\(name)", name: name, lightIDs: ids.sorted { $0.raw < $1.raw })
            }
            .sorted { $0.name < $1.name }
    }

    public func setPower(_ on: Bool, lights ids: [LightID]) async throws {
        try await callService(
            on ? "turn_on" : "turn_off",
            data: ["entity_id": ids.map(\.raw)]
        )
        applyLocal(ids) { $0.state.isOn = on }
    }

    public func setBrightness(_ value: Double, lights ids: [LightID]) async throws {
        try await callService(
            "turn_on",
            data: [
                "entity_id": ids.map(\.raw),
                "brightness": Int(min(max(value, 0), 1) * 255),
            ]
        )
        applyLocal(ids) {
            $0.state.brightness = value
            if value > 0 { $0.state.isOn = true }
        }
    }

    public func setColor(_ color: PHColor, lights ids: [LightID]) async throws {
        let rgb = color.rgb255
        try await callService(
            "turn_on",
            data: [
                "entity_id": ids.map(\.raw),
                "rgb_color": [rgb.red, rgb.green, rgb.blue],
            ]
        )
        applyLocal(ids) {
            $0.state.color = color
            $0.state.mirek = nil
            $0.state.isOn = true
        }
    }

    public func applyNativeGradient(_ points: [PHColor], to light: LightID) async throws {
        // HA has no generic gradient call; use the first point.
        if let first = points.first {
            try await setColor(first, lights: [light])
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

    // MARK: Service calls

    private func callService(_ service: String, data: [String: Any]) async throws {
        guard let connection else { throw ProviderError("Home Assistant is not connected.") }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                .callService(
                    domain: "light",
                    service: HAServicesService(rawValue: service),
                    data: data
                )
            ) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: ProviderError("Home Assistant: \(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: States

    private func subscribeToStates(_ connection: HAConnection) {
        statesCancellable?.cancel()
        statesCancellable = connection.caches.states().subscribe { [weak self] _, states in
            // HAKit calls back on the main queue; hop to the actor.
            Task { await self?.ingest(states: states) }
        }
    }

    private func ingest(states: HACachedStates) {
        var mapped: [String: Light] = [:]
        for entity in states.all where entity.domain == "light" {
            let light = mapLight(entity)
            mapped[light.id.raw] = light
        }
        lightsByID = mapped
        broadcast(.lightsReplaced(Array(mapped.values)))
    }

    private func mapLight(_ entity: HAEntity) -> Light {
        let attributes = entity.attributes.dictionary
        let supportedModes = (attributes["supported_color_modes"] as? [String]) ?? []

        var capabilities: LightCapabilities = [.power]
        let colorModes: Set<String> = ["hs", "xy", "rgb", "rgbw", "rgbww"]
        if supportedModes.contains(where: { colorModes.contains($0) }) {
            capabilities.insert(.color)
        }
        if supportedModes.contains("color_temp") {
            capabilities.insert(.colorTemperature)
        }
        if !supportedModes.isEmpty, supportedModes != ["onoff"] {
            capabilities.insert(.dimming)
        }

        let isOn = entity.state == "on"
        let brightness255 = (attributes["brightness"] as? Int) ?? (isOn ? 255 : 0)

        var color: PHColor?
        if let rgb = attributes["rgb_color"] as? [Int], rgb.count >= 3 {
            color = PHColor(red255: rgb[0], green255: rgb[1], blue255: rgb[2])
        }

        var mirek: Int?
        if color == nil, let kelvin = attributes["color_temp_kelvin"] as? Int, kelvin > 0 {
            mirek = 1_000_000 / kelvin
        }

        let entry = registry.entities[entity.entityId]
        let areaID = entry?.areaID ?? entry?.deviceID.flatMap { registry.deviceAreas[$0] }
        let areaName = areaID.flatMap { registry.areaNames[$0] }

        return Light(
            id: LightID(provider: id, raw: entity.entityId),
            name: entity.attributes.friendlyName ?? entity.entityId,
            room: areaName,
            capabilities: capabilities,
            state: LightState(
                isOn: isOn,
                brightness: Double(brightness255) / 255.0,
                color: color,
                mirek: mirek,
                isReachable: entity.state != "unavailable"
            ),
            dedupeHints: DedupeHints(
                uniqueID: entry?.uniqueID?.lowercased(),
                sourcePlatform: entry?.platform
            )
        )
    }

    private func applyLocal(_ ids: [LightID], _ change: (inout Light) -> Void) {
        for lightID in ids {
            guard var light = lightsByID[lightID.raw] else { continue }
            change(&light)
            lightsByID[lightID.raw] = light
            broadcast(.lightUpdated(light))
        }
    }

    // MARK: Event broadcast

    private func removeContinuation(_ key: UUID) {
        continuations[key] = nil
    }

    private func broadcast(_ event: ProviderEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
}
