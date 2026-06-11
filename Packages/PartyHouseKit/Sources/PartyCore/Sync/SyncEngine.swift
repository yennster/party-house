import Foundation

/// Persists app configuration (provider connections, zones, palettes, dedupe
/// overrides) and mirrors it through iCloud Key-Value Storage so an iPhone and a Mac
/// share one setup.
///
/// Layering:
///   - App Group UserDefaults is the source of truth on-device (widgets read it too).
///   - NSUbiquitousKeyValueStore mirrors every key cross-device; external changes
///     are folded back into the app group and observers are notified.
///   - Secrets never travel through this type — see `KeychainStore`.
public final class SyncEngine: @unchecked Sendable {
    public static let appGroupID = "group.io.github.yennster.partyhouse"

    public static let shared = SyncEngine()

    private let defaults: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore?
    private let queue = DispatchQueue(label: "io.github.yennster.partyhouse.sync")
    private var observers: [UUID: @Sendable () -> Void] = [:]

    /// Keys mirrored to iCloud. Everything else stays device-local.
    private static let syncedKeyPrefix = "sync."

    public init(
        defaults: UserDefaults? = nil,
        cloudEnabled: Bool = !ProcessInfo.processInfo.arguments.contains("-DisableCloudSync")
    ) {
        self.defaults = defaults ?? UserDefaults(suiteName: SyncEngine.appGroupID) ?? .standard
        self.cloud = cloudEnabled ? NSUbiquitousKeyValueStore.default : nil

        if let cloud {
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: cloud,
                queue: .main
            ) { [weak self] note in
                self?.mergeExternalChanges(note)
            }
            cloud.synchronize()
            pullAllFromCloud()
        }
    }

    // MARK: Codable storage

    public func save<T: Encodable>(_ value: T, forKey key: String, synced: Bool = true) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let fullKey = synced ? Self.syncedKeyPrefix + key : key
        defaults.set(data, forKey: fullKey)
        if synced, let cloud {
            cloud.set(data, forKey: fullKey)
            cloud.synchronize()
        }
    }

    public func load<T: Decodable>(_ type: T.Type, forKey key: String, synced: Bool = true) -> T? {
        let fullKey = synced ? Self.syncedKeyPrefix + key : key
        guard let data = defaults.data(forKey: fullKey) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    public func remove(forKey key: String, synced: Bool = true) {
        let fullKey = synced ? Self.syncedKeyPrefix + key : key
        defaults.removeObject(forKey: fullKey)
        if synced, let cloud {
            cloud.removeObject(forKey: fullKey)
            cloud.synchronize()
        }
    }

    // MARK: Change observation

    /// Fires on the main queue whenever another device changed synced settings.
    @discardableResult
    public func observeExternalChanges(_ handler: @escaping @Sendable () -> Void) -> UUID {
        let id = UUID()
        queue.sync { observers[id] = handler }
        return id
    }

    public func removeObserver(_ id: UUID) {
        queue.sync { _ = observers.removeValue(forKey: id) }
    }

    // MARK: Cloud merge

    private func mergeExternalChanges(_ note: Notification) {
        guard let cloud else { return }
        let changedKeys = (note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? []
        var didChange = false
        for key in changedKeys where key.hasPrefix(Self.syncedKeyPrefix) {
            if let data = cloud.data(forKey: key) {
                defaults.set(data, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            didChange = true
        }
        guard didChange else { return }
        let handlers = queue.sync { Array(observers.values) }
        for handler in handlers { handler() }
    }

    private func pullAllFromCloud() {
        guard let cloud else { return }
        for (key, value) in cloud.dictionaryRepresentation where key.hasPrefix(Self.syncedKeyPrefix) {
            // Local values win only when the cloud has nothing; otherwise the most
            // recent writer already replaced the cloud copy.
            if let data = value as? Data, defaults.data(forKey: key) == nil {
                defaults.set(data, forKey: key)
            }
        }
    }
}

public extension SyncEngine {
    enum Keys {
        public static let zones = "zones.v1"
        public static let customPalettes = "palettes.custom.v1"
        public static let providerConfigs = "providers.v1"
        public static let dedupeOverrides = "dedupe.overrides.v1"
    }
}
