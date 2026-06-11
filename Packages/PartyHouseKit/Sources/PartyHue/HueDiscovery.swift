import Foundation
import Network
import PartyCore

public struct DiscoveredBridge: Identifiable, Hashable, Sendable {
    public let bridgeID: String
    public let host: String
    public let name: String?

    public var id: String { bridgeID }

    public init(bridgeID: String, host: String, name: String? = nil) {
        self.bridgeID = bridgeID
        self.host = host
        self.name = name
    }
}

/// Finds Hue bridges on the network: mDNS (`_hue._tcp`) first, then the Signify
/// cloud broker (`discovery.meethue.com`), plus manual address verification.
public enum HueDiscovery {
    public static func discover(timeout: TimeInterval = 4) async -> [DiscoveredBridge] {
        var found: [String: DiscoveredBridge] = [:]

        for bridge in await discoverViaMDNS(timeout: timeout) {
            found[bridge.bridgeID] = bridge
        }
        if found.isEmpty {
            for bridge in await discoverViaCloud() {
                found[bridge.bridgeID] = bridge
            }
        }
        return found.values.sorted { $0.bridgeID < $1.bridgeID }
    }

    /// Confirms a manually entered host is a Hue bridge and returns its identity.
    public static func verify(host: String) async throws -> DiscoveredBridge {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://\(trimmed)/api/0/config") else {
            throw ProviderError("That doesn't look like a valid address.")
        }
        let session = URLSession(configuration: .ephemeral, delegate: HueBridgeTrustDelegate(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let (data, _) = try await session.data(for: request)
        let info = try JSONDecoder().decode(HueBridgeInfo.self, from: data)
        guard let bridgeID = info.bridgeid else {
            throw ProviderError("No Hue bridge responded at \(trimmed).")
        }
        return DiscoveredBridge(bridgeID: bridgeID.lowercased(), host: trimmed, name: info.name)
    }

    // MARK: mDNS

    static func discoverViaMDNS(timeout: TimeInterval) async -> [DiscoveredBridge] {
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_hue._tcp", domain: nil),
            using: NWParameters()
        )

        final class Collector: @unchecked Sendable {
            let lock = NSLock()
            var finished = false
            var collected: [(NWEndpoint, String?)] = []
        }
        let collector = Collector()

        let endpoints: [(NWEndpoint, String?)] = await withCheckedContinuation { continuation in
            @Sendable func finish() {
                collector.lock.lock()
                defer { collector.lock.unlock() }
                guard !collector.finished else { return }
                collector.finished = true
                browser.cancel()
                continuation.resume(returning: collector.collected)
            }

            browser.browseResultsChangedHandler = { results, _ in
                collector.lock.lock()
                collector.collected = results.map { result in
                    var bridgeID: String?
                    if case .bonjour(let txt) = result.metadata {
                        bridgeID = txt.dictionary["bridgeid"]
                    }
                    return (result.endpoint, bridgeID)
                }
                collector.lock.unlock()
            }
            browser.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish() }
        }

        var bridges: [DiscoveredBridge] = []
        for (endpoint, bridgeID) in endpoints {
            guard let host = await resolveHost(for: endpoint) else { continue }
            if let bridgeID {
                bridges.append(DiscoveredBridge(bridgeID: bridgeID.lowercased(), host: host))
            } else if let verified = try? await verify(host: host) {
                bridges.append(verified)
            }
        }
        return bridges
    }

    /// Resolves a Bonjour service endpoint to a concrete IP by opening a connection.
    static func resolveHost(for endpoint: NWEndpoint, timeout: TimeInterval = 3) async -> String? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(to: endpoint, using: .tcp)
            let lock = NSLock()
            var resumed = false

            func finish(_ value: String?) {
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
                    if let inner = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, _) = inner {
                        switch host {
                        case .ipv4(let address):
                            finish("\(address)".components(separatedBy: "%").first)
                        case .ipv6(let address):
                            finish("[\("\(address)".components(separatedBy: "%").first ?? "")]")
                        case .name(let name, _):
                            finish(name)
                        @unknown default:
                            finish(nil)
                        }
                    } else {
                        finish(nil)
                    }
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    // MARK: Cloud broker

    struct CloudEntry: Decodable {
        let id: String
        let internalipaddress: String
    }

    static func discoverViaCloud() async -> [DiscoveredBridge] {
        guard let url = URL(string: "https://discovery.meethue.com") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let entries = try? JSONDecoder().decode([CloudEntry].self, from: data) else {
            return []
        }
        return entries.map {
            DiscoveredBridge(bridgeID: $0.id.lowercased(), host: $0.internalipaddress)
        }
    }
}
