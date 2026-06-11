import Foundation
import PartyCore

/// Philips Hue integration over the local CLIP v2 API with live updates via the
/// bridge's server-sent-events stream.
public actor HueProvider: LightProvider {
    public nonisolated let id: ProviderID
    public nonisolated let displayName = "Philips Hue"

    private let bridgeID: String
    private let client: HueClient
    private var lightsByID: [String: Light] = [:]
    private var groups: [ProviderGroup] = []
    /// grouped_light id covering the whole bridge ("bridge_home"), if known.
    private var bridgeHomeGroupedLightID: String?
    private var sseTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<ProviderEvent>.Continuation] = [:]

    public init(bridgeID: String, host: String, applicationKey: String) {
        self.bridgeID = bridgeID
        self.id = .hue(bridgeID: bridgeID)
        self.client = HueClient(host: host, applicationKey: applicationKey)
    }

    // MARK: LightProvider

    public func connect() async throws {
        broadcast(.connectionChanged(.connecting))
        do {
            try await reload()
            startEventStream()
            broadcast(.connectionChanged(.connected))
        } catch {
            broadcast(.connectionChanged(.failed(error.localizedDescription)))
            throw error
        }
    }

    public func disconnect() async {
        sseTask?.cancel()
        sseTask = nil
        broadcast(.connectionChanged(.disconnected))
    }

    public func lights() async throws -> [Light] {
        Array(lightsByID.values)
    }

    public func nativeGroups() async throws -> [ProviderGroup] {
        groups
    }

    public func setPower(_ on: Bool, lights ids: [LightID]) async throws {
        // A whole-house command collapses into one grouped_light call.
        if let groupedID = bridgeHomeGroupedLightID,
           Set(ids.map(\.raw)) == Set(lightsByID.keys) {
            try await client.put(
                path: "/clip/v2/resource/grouped_light/\(groupedID)",
                body: HuePayloads.power(on)
            )
            applyLocal(ids) { $0.state.isOn = on }
            return
        }

        try await fanOut(ids, payload: HuePayloads.power(on))
        applyLocal(ids) { $0.state.isOn = on }
    }

    public func setBrightness(_ value: Double, lights ids: [LightID]) async throws {
        try await fanOut(ids, payload: HuePayloads.brightness(value))
        applyLocal(ids) {
            $0.state.brightness = value
            if value > 0 { $0.state.isOn = true }
        }
    }

    public func setColor(_ color: PHColor, lights ids: [LightID]) async throws {
        try await fanOut(ids, payload: HuePayloads.color(color))
        applyLocal(ids) {
            $0.state.color = color
            $0.state.mirek = nil
            $0.state.isOn = true
        }
    }

    public func applyNativeGradient(_ points: [PHColor], to light: LightID) async throws {
        try await client.put(
            path: "/clip/v2/resource/light/\(light.raw)",
            body: HuePayloads.gradient(points)
        )
        applyLocal([light]) {
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

    // MARK: Fetch & map

    private func reload() async throws {
        async let lightResources = client.fetch(HueLightResource.self, path: "/clip/v2/resource/light")
        async let deviceResources = client.fetch(HueDeviceResource.self, path: "/clip/v2/resource/device")
        async let roomResources = client.fetch(HueGroupResource.self, path: "/clip/v2/resource/room")
        async let zoneResources = client.fetch(HueGroupResource.self, path: "/clip/v2/resource/zone")
        async let homeResources = client.fetch(HueGroupResource.self, path: "/clip/v2/resource/bridge_home")

        let (fetchedLights, devices, rooms, zones, homes) = try await (
            lightResources, deviceResources, roomResources, zoneResources, homeResources
        )

        bridgeHomeGroupedLightID = homes.first?.groupedLightID

        // device id -> light resource ids, for room membership.
        let lightsByDevice = Dictionary(
            uniqueKeysWithValues: devices.map { ($0.id, $0.lightServiceIDs) }
        )
        // light id -> room name.
        var roomNameByLight: [String: String] = [:]
        for room in rooms {
            guard let roomName = room.metadata?.name else { continue }
            for child in room.children where child.rtype == "device" {
                for lightID in lightsByDevice[child.rid] ?? [] {
                    roomNameByLight[lightID] = roomName
                }
            }
        }

        lightsByID = Dictionary(
            uniqueKeysWithValues: fetchedLights.map { resource in
                (resource.id, mapLight(resource, roomName: roomNameByLight[resource.id]))
            }
        )

        var mappedGroups: [ProviderGroup] = []
        for room in rooms {
            guard let name = room.metadata?.name else { continue }
            let memberIDs = room.children
                .filter { $0.rtype == "device" }
                .flatMap { lightsByDevice[$0.rid] ?? [] }
                .filter { lightsByID[$0] != nil }
                .map { LightID(provider: id, raw: $0) }
            if !memberIDs.isEmpty {
                mappedGroups.append(ProviderGroup(id: room.id, name: name, lightIDs: memberIDs))
            }
        }
        for zone in zones {
            guard let name = zone.metadata?.name else { continue }
            let memberIDs = zone.children
                .filter { $0.rtype == "light" }
                .map(\.rid)
                .filter { lightsByID[$0] != nil }
                .map { LightID(provider: id, raw: $0) }
            if !memberIDs.isEmpty {
                mappedGroups.append(ProviderGroup(id: zone.id, name: name, lightIDs: memberIDs))
            }
        }
        groups = mappedGroups.sorted { $0.name < $1.name }

        broadcast(.lightsReplaced(Array(lightsByID.values)))
    }

    private func mapLight(_ resource: HueLightResource, roomName: String?) -> Light {
        var capabilities: LightCapabilities = [.power]
        if resource.dimming != nil { capabilities.insert(.dimming) }
        if resource.color != nil { capabilities.insert(.color) }
        if resource.colorTemperature != nil { capabilities.insert(.colorTemperature) }
        if resource.gradient != nil { capabilities.insert(.nativeGradient) }

        var color: PHColor?
        if let xy = resource.color?.xy {
            let brightness = (resource.dimming?.brightness ?? 100) / 100.0
            color = ColorMath.color(
                fromXY: XYColor(x: xy.x, y: xy.y),
                brightness: max(brightness * 0.8, 0.05)
            )
        }

        return Light(
            id: LightID(provider: id, raw: resource.id),
            name: resource.metadata?.name ?? "Hue Light",
            room: roomName,
            capabilities: capabilities,
            state: LightState(
                isOn: resource.on?.on ?? false,
                brightness: (resource.dimming?.brightness ?? 100) / 100.0,
                color: color,
                mirek: resource.colorTemperature?.mirek
            ),
            dedupeHints: DedupeHints(uniqueID: resource.id.lowercased(), sourcePlatform: "hue")
        )
    }

    // MARK: Commands

    private func fanOut(_ ids: [LightID], payload: [String: Any]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for lightID in ids {
                group.addTask { [client] in
                    try await client.put(
                        path: "/clip/v2/resource/light/\(lightID.raw)",
                        body: payload
                    )
                }
            }
            try await group.waitForAll()
        }
    }

    private func applyLocal(_ ids: [LightID], _ change: (inout Light) -> Void) {
        for lightID in ids {
            guard var light = lightsByID[lightID.raw] else { continue }
            change(&light)
            lightsByID[lightID.raw] = light
            broadcast(.lightUpdated(light))
        }
    }

    // MARK: SSE

    private func startEventStream() {
        sseTask?.cancel()
        sseTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.consumeEventStream()
                } catch is CancellationError {
                    return
                } catch {
                    // Stream dropped (sleep, network blip) — retry shortly.
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }

    private func consumeEventStream() async throws {
        let (_, lines) = try await client.eventStreamLines()
        for try await line in lines {
            guard line.hasPrefix("data:") else { continue }
            let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = json.data(using: .utf8),
                  let events = try? JSONDecoder().decode([HueEvent].self, from: data) else { continue }
            for event in events where event.type == "update" {
                for update in event.data where update.type == "light" {
                    apply(update)
                }
            }
        }
    }

    private func apply(_ update: HueEventData) {
        guard var light = lightsByID[update.id] else { return }
        if let on = update.on { light.state.isOn = on.on }
        if let dimming = update.dimming { light.state.brightness = dimming.brightness / 100.0 }
        if let xy = update.color?.xy {
            light.state.color = ColorMath.color(
                fromXY: XYColor(x: xy.x, y: xy.y),
                brightness: max(light.state.brightness * 0.8, 0.05)
            )
            light.state.mirek = nil
        }
        if let mirek = update.colorTemperature?.mirek {
            light.state.mirek = mirek
            light.state.color = nil
        }
        lightsByID[update.id] = light
        broadcast(.lightUpdated(light))
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
