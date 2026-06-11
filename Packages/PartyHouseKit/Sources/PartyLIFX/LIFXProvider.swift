import Foundation
import Network
import PartyCore

/// LIFX LAN integration. Marked beta in the UI — it follows the published LAN
/// protocol but is untested against real hardware. State is polled (the LAN
/// protocol has no push channel).
public actor LIFXProvider: LightProvider {
    public nonisolated let id: ProviderID = .lifx
    public nonisolated let displayName = "LIFX"

    private let manualHosts: [String]
    private let source: UInt32 = 0x50_41_52_54 // "PART"
    private var sequence: UInt8 = 0

    private var devices: [String: LIFXDevice] = [:] // serialString -> device
    private var lightsByID: [String: Light] = [:]
    private var lastHSBK: [String: LIFXPacket.HSBK] = [:]
    private var pollTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<ProviderEvent>.Continuation] = [:]

    public init(manualHosts: [String] = []) {
        self.manualHosts = manualHosts
    }

    // MARK: LightProvider

    public func connect() async throws {
        broadcast(.connectionChanged(.connecting))
        await rediscover()
        startPolling()
        broadcast(.connectionChanged(.connected))
    }

    public func disconnect() async {
        pollTask?.cancel()
        pollTask = nil
        broadcast(.connectionChanged(.disconnected))
    }

    public func lights() async throws -> [Light] {
        Array(lightsByID.values)
    }

    public func nativeGroups() async throws -> [ProviderGroup] {
        guard !lightsByID.isEmpty else { return [] }
        return [
            ProviderGroup(
                id: "lifx-all",
                name: "LIFX Lights",
                lightIDs: lightsByID.values.map(\.id)
            )
        ]
    }

    public func setPower(_ on: Bool, lights ids: [LightID]) async throws {
        for lightID in ids {
            guard let device = devices[lightID.raw] else { continue }
            let packet = LIFXPacket.setLightPower(
                source: source,
                sequence: nextSequence(),
                target: device.serial,
                on: on
            )
            await send(packet, to: device.host)
            updateLocal(lightID.raw) { $0.state.isOn = on }
        }
    }

    public func setBrightness(_ value: Double, lights ids: [LightID]) async throws {
        for lightID in ids {
            guard let device = devices[lightID.raw] else { continue }
            var hsbk = lastHSBK[lightID.raw] ?? LIFXPacket.HSBK(hue: 0, saturation: 0, brightness: 65535, kelvin: 3500)
            hsbk.brightness = UInt16(min(max(value, 0), 1) * 65535)
            lastHSBK[lightID.raw] = hsbk
            let packet = LIFXPacket.setColor(
                source: source,
                sequence: nextSequence(),
                target: device.serial,
                color: hsbk
            )
            await send(packet, to: device.host)
            updateLocal(lightID.raw) {
                $0.state.brightness = value
                if value > 0 { $0.state.isOn = true }
            }
        }
    }

    public func setColor(_ color: PHColor, lights ids: [LightID]) async throws {
        let hsbk = Self.hsbk(from: color)
        for lightID in ids {
            guard let device = devices[lightID.raw] else { continue }
            lastHSBK[lightID.raw] = hsbk
            let packet = LIFXPacket.setColor(
                source: source,
                sequence: nextSequence(),
                target: device.serial,
                color: hsbk
            )
            await send(packet, to: device.host)
            // LIFX keeps power state separate from color, so wake the bulb too.
            let power = LIFXPacket.setLightPower(
                source: source,
                sequence: nextSequence(),
                target: device.serial,
                on: true
            )
            await send(power, to: device.host)
            updateLocal(lightID.raw) {
                $0.state.color = color
                $0.state.isOn = true
            }
        }
    }

    public func applyNativeGradient(_ points: [PHColor], to light: LightID) async throws {
        // Multizone strips aren't detected yet; fall back to the first color.
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

    // MARK: Discovery & polling

    private func rediscover() async {
        let found = await LIFXDiscovery.discover(manualHosts: manualHosts, source: source)
        devices = Dictionary(uniqueKeysWithValues: found.map { ($0.serialString, $0) })
        await refreshStates()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await self?.refreshStates()
            }
        }
    }

    private func refreshStates() async {
        for (serial, device) in devices {
            let packet = LIFXPacket.getColor(source: source, sequence: nextSequence(), target: device.serial)
            guard let reply = await sendAndReceive(packet, to: device.host),
                  let state = LIFXPacket.parseLightState(reply) else { continue }

            lastHSBK[serial] = state.color
            let brightness = Double(state.color.brightness) / 65535.0
            let saturation = Double(state.color.saturation) / 65535.0
            let color: PHColor?
            if saturation > 0.05 {
                color = Self.color(from: state.color)
            } else {
                color = nil
            }

            let light = Light(
                id: LightID(provider: id, raw: serial),
                name: state.label.isEmpty ? "LIFX \(serial.suffix(6))" : state.label,
                room: nil,
                capabilities: [.power, .dimming, .color, .colorTemperature],
                state: LightState(
                    isOn: state.isOn,
                    brightness: brightness,
                    color: color,
                    mirek: saturation <= 0.05 ? Int(1_000_000 / max(UInt32(state.color.kelvin), 1500)) : nil
                ),
                dedupeHints: DedupeHints(uniqueID: serial, sourcePlatform: "lifx")
            )
            lightsByID[serial] = light
            broadcast(.lightUpdated(light))
        }
    }

    // MARK: UDP plumbing

    private func send(_ data: Data, to host: String) async {
        _ = await sendAndReceive(data, to: host, expectReply: false)
    }

    private func sendAndReceive(_ data: Data, to host: String, expectReply: Bool = true) async -> Data? {
        await withCheckedContinuation { continuation in
            guard let port = NWEndpoint.Port(rawValue: LIFXPacket.port) else {
                continuation.resume(returning: nil)
                return
            }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .udp)
            let lock = NSLock()
            var resumed = false

            func finish(_ value: Data?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if error != nil {
                            finish(nil)
                        } else if !expectReply {
                            finish(nil)
                        }
                    })
                    if expectReply {
                        connection.receiveMessage { content, _, _, _ in
                            finish(content)
                        }
                    }
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { finish(nil) }
        }
    }

    private func nextSequence() -> UInt8 {
        sequence &+= 1
        return sequence
    }

    private func updateLocal(_ serial: String, _ change: (inout Light) -> Void) {
        guard var light = lightsByID[serial] else { return }
        change(&light)
        lightsByID[serial] = light
        broadcast(.lightUpdated(light))
    }

    // MARK: Color conversion

    static func hsbk(from color: PHColor) -> LIFXPacket.HSBK {
        let (hue, saturation, brightness) = rgbToHSB(color)
        return LIFXPacket.HSBK(
            hue: UInt16(min(max(hue / 360.0, 0), 1) * 65535),
            saturation: UInt16(min(max(saturation, 0), 1) * 65535),
            brightness: UInt16(min(max(brightness, 0), 1) * 65535),
            kelvin: 3500
        )
    }

    static func color(from hsbk: LIFXPacket.HSBK) -> PHColor {
        hsbToRGB(
            hue: Double(hsbk.hue) / 65535.0 * 360.0,
            saturation: Double(hsbk.saturation) / 65535.0,
            brightness: Double(hsbk.brightness) / 65535.0
        )
    }

    static func rgbToHSB(_ color: PHColor) -> (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(color.red, color.green, color.blue)
        let minValue = min(color.red, color.green, color.blue)
        let delta = maxValue - minValue

        var hue = 0.0
        if delta > 0 {
            if maxValue == color.red {
                hue = 60 * ((color.green - color.blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == color.green {
                hue = 60 * ((color.blue - color.red) / delta + 2)
            } else {
                hue = 60 * ((color.red - color.green) / delta + 4)
            }
        }
        if hue < 0 { hue += 360 }

        let saturation = maxValue == 0 ? 0 : delta / maxValue
        return (hue, saturation, maxValue)
    }

    static func hsbToRGB(hue: Double, saturation: Double, brightness: Double) -> PHColor {
        let c = brightness * saturation
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c

        let (r, g, b): (Double, Double, Double)
        switch hue {
        case 0..<60: (r, g, b) = (c, x, 0)
        case 60..<120: (r, g, b) = (x, c, 0)
        case 120..<180: (r, g, b) = (0, c, x)
        case 180..<240: (r, g, b) = (0, x, c)
        case 240..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return PHColor(red: r + m, green: g + m, blue: b + m)
    }

    private func removeContinuation(_ key: UUID) {
        continuations[key] = nil
    }

    private func broadcast(_ event: ProviderEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
}
