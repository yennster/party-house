import Foundation

public struct HueBridgeConfig: Codable, Hashable, Sendable, Identifiable {
    /// The bridge's own id (from discovery / config endpoint).
    public var bridgeID: String
    /// IP or hostname on the local network.
    public var host: String

    public var id: String { bridgeID }

    public init(bridgeID: String, host: String) {
        self.bridgeID = bridgeID
        self.host = host
    }
}

public struct HomeAssistantConfig: Codable, Hashable, Sendable {
    /// URL reachable at home, e.g. http://homeassistant.local:8123
    public var internalURL: String
    /// URL reachable from anywhere (Nabu Casa, Cloudflare Tunnel, ...). Optional.
    public var externalURL: String?

    public init(internalURL: String, externalURL: String? = nil) {
        self.internalURL = internalURL
        self.externalURL = externalURL
    }

    public var urls: [URL] {
        [internalURL, externalURL]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .compactMap(URL.init(string:))
    }

    /// Cleans up a user-typed address: trims whitespace, adds a scheme when
    /// missing (https for public hostnames, http for .local/IP addresses, which
    /// rarely have certificates), and drops trailing slashes.
    public static func normalized(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        if !text.contains("://") {
            let host = text.split(separator: "/").first.map(String.init) ?? text
            let bareHost = host.split(separator: ":").first.map(String.init) ?? host
            let isLocalish = bareHost.hasSuffix(".local")
                || bareHost == "localhost"
                || bareHost.allSatisfy { $0.isNumber || $0 == "." }
            text = (isLocalish ? "http://" : "https://") + text
        }

        while text.hasSuffix("/") {
            text.removeLast()
        }
        return text
    }
}

public struct LIFXConfig: Codable, Hashable, Sendable {
    public var enabled: Bool
    /// Manually entered IPs, in addition to subnet discovery.
    public var manualHosts: [String]

    public init(enabled: Bool = false, manualHosts: [String] = []) {
        self.enabled = enabled
        self.manualHosts = manualHosts
    }
}

/// Everything needed to reconstruct provider connections on any of the user's
/// devices. Synced via iCloud KVS; secrets live in the keychain keyed by these ids.
public struct ProviderConfigs: Codable, Sendable, Equatable {
    public var hueBridges: [HueBridgeConfig]
    public var homeAssistant: HomeAssistantConfig?
    public var lifx: LIFXConfig

    public init(
        hueBridges: [HueBridgeConfig] = [],
        homeAssistant: HomeAssistantConfig? = nil,
        lifx: LIFXConfig = LIFXConfig()
    ) {
        self.hueBridges = hueBridges
        self.homeAssistant = homeAssistant
        self.lifx = lifx
    }

    public static func load(from sync: SyncEngine = .shared) -> ProviderConfigs {
        sync.load(ProviderConfigs.self, forKey: SyncEngine.Keys.providerConfigs) ?? ProviderConfigs()
    }

    public func save(to sync: SyncEngine = .shared) {
        sync.save(self, forKey: SyncEngine.Keys.providerConfigs)
    }
}
