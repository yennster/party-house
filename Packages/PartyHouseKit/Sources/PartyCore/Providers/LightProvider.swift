import Foundation

public enum ProviderConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

public enum ProviderEvent: Sendable {
    /// Full snapshot of every light the provider knows about.
    case lightsReplaced([Light])
    /// Incremental update for a single light.
    case lightUpdated(Light)
    case connectionChanged(ProviderConnectionState)
}

/// One connected lighting integration (a Hue bridge, a Home Assistant server, the
/// LIFX LAN, or the demo house).
///
/// Commands are batch-first so providers can collapse a zone operation into a native
/// group call (Hue grouped_light, HA area target) or fan out internally with their own
/// rate limiting.
public protocol LightProvider: Actor {
    nonisolated var id: ProviderID { get }
    nonisolated var displayName: String { get }

    func connect() async throws
    func disconnect() async

    func lights() async throws -> [Light]
    func nativeGroups() async throws -> [ProviderGroup]

    func setPower(_ on: Bool, lights: [LightID]) async throws
    /// brightness 0...1
    func setBrightness(_ value: Double, lights: [LightID]) async throws
    func setColor(_ color: PHColor, lights: [LightID]) async throws
    /// Only called for lights with the `.nativeGradient` capability.
    func applyNativeGradient(_ points: [PHColor], to light: LightID) async throws

    /// Long-lived stream of state changes. Each call may create a new stream.
    func events() async -> AsyncStream<ProviderEvent>
}

public struct ProviderError: LocalizedError, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}
