import XCTest
@testable import PartyCore

@MainActor
final class ZoneStoreTests: XCTestCase {
    private func makeSync() -> SyncEngine {
        let defaults = UserDefaults(suiteName: "zone-tests-\(UUID().uuidString)")!
        return SyncEngine(defaults: defaults, cloudEnabled: false)
    }

    func testAddPersistsAndReloads() {
        let sync = makeSync()
        let store = ZoneStore(sync: sync)
        store.add(Zone(name: "Party Floor", lightIDs: [LightID(provider: .demo, raw: "a")]))

        let reloaded = ZoneStore(sync: sync)
        XCTAssertEqual(reloaded.zones.count, 1)
        XCTAssertEqual(reloaded.zones.first?.name, "Party Floor")
    }

    func testImportNativeGroupSkipsDuplicateNames() {
        let store = ZoneStore(sync: makeSync())
        let group = ProviderGroup(id: "g1", name: "Kitchen", lightIDs: [LightID(provider: .demo, raw: "k1")])
        store.importNativeGroup(group)
        store.importNativeGroup(group)
        XCTAssertEqual(store.zones.count, 1)
    }

    func testPruneRemovesDeadLights() {
        let store = ZoneStore(sync: makeSync())
        let alive = LightID(provider: .demo, raw: "alive")
        let dead = LightID(provider: .demo, raw: "dead")
        store.add(Zone(name: "Mixed", lightIDs: [alive, dead]))

        store.prune(existing: [alive])
        XCTAssertEqual(store.zones.first?.lightIDs, [alive])
    }

    func testDeleteAndUpdate() {
        let store = ZoneStore(sync: makeSync())
        var zone = Zone(name: "Old Name")
        store.add(zone)

        zone.name = "New Name"
        store.update(zone)
        XCTAssertEqual(store.zones.first?.name, "New Name")

        store.delete(zone.id)
        XCTAssertTrue(store.zones.isEmpty)
    }
}
