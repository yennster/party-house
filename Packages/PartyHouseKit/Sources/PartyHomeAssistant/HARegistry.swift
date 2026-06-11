import Foundation
import HAKit

/// Entity/device/area registry data, fetched once per connection. Used to resolve
/// area names (HA's rooms) and unique_ids (for Hue dedupe).
struct HARegistrySnapshot: Sendable {
    struct EntityEntry: Sendable {
        let entityID: String
        let uniqueID: String?
        let platform: String?
        let areaID: String?
        let deviceID: String?
    }

    var entities: [String: EntityEntry] = [:]
    var deviceAreas: [String: String] = [:] // device_id -> area_id
    var areaNames: [String: String] = [:]   // area_id -> name

    static func fetch(connection: HAConnection) async -> HARegistrySnapshot {
        async let entityData = send(connection, command: "config/entity_registry/list")
        async let deviceData = send(connection, command: "config/device_registry/list")
        async let areaData = send(connection, command: "config/area_registry/list")

        var snapshot = HARegistrySnapshot()

        if let items = arrayOfDictionaries(await entityData) {
            for item in items {
                guard let entityID = item["entity_id"] as? String else { continue }
                snapshot.entities[entityID] = EntityEntry(
                    entityID: entityID,
                    uniqueID: stringValue(item["unique_id"]),
                    platform: item["platform"] as? String,
                    areaID: item["area_id"] as? String,
                    deviceID: item["device_id"] as? String
                )
            }
        }
        if let items = arrayOfDictionaries(await deviceData) {
            for item in items {
                guard let deviceID = item["id"] as? String,
                      let areaID = item["area_id"] as? String else { continue }
                snapshot.deviceAreas[deviceID] = areaID
            }
        }
        if let items = arrayOfDictionaries(await areaData) {
            for item in items {
                guard let areaID = item["area_id"] as? String,
                      let name = item["name"] as? String else { continue }
                snapshot.areaNames[areaID] = name
            }
        }
        return snapshot
    }

    private static func send(_ connection: HAConnection, command: String) async -> HAData? {
        await withCheckedContinuation { continuation in
            connection.send(HARequest(type: .webSocket(command))) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func arrayOfDictionaries(_ data: HAData?) -> [[String: Any]]? {
        guard case .array(let items)? = data else { return nil }
        return items.compactMap { item in
            if case .dictionary(let dict) = item { return dict }
            return nil
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let value { return "\(value)" }
        return nil
    }
}

/// Picks the first reachable Home Assistant URL — internal first, then external —
/// mirroring how the official companion app fails over.
enum HAURLSelector {
    static func pickReachableURL(from urls: [URL], token: String, timeout: TimeInterval = 3) async -> URL? {
        for url in urls {
            if await isReachable(url, token: token, timeout: timeout) {
                return url
            }
        }
        return nil
    }

    static func isReachable(_ url: URL, token: String, timeout: TimeInterval) async -> Bool {
        var request = URLRequest(url: url.appendingPathComponent("api/"))
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return false
        }
        // 200 = ok; 401/403 still proves the server is there (bad token surfaces later).
        return (200..<500).contains(http.statusCode)
    }
}
