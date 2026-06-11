import XCTest
@testable import PartyCore

@MainActor
final class DedupeTests: XCTestCase {
    private func makeStore() -> LightsStore {
        let suiteName = "dedupe-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sync = SyncEngine(defaults: defaults, cloudEnabled: false)
        return LightsStore(zoneStore: ZoneStore(sync: sync), sync: sync)
    }

    func testHueLightBridgedThroughHAIsSuppressed() async {
        let store = makeStore()
        let hueLight = Light(
            id: LightID(provider: .hue(bridgeID: "bridge1"), raw: "AAAA-BBBB"),
            name: "Couch Lamp",
            capabilities: [.power, .color]
        )
        let haEcho = Light(
            id: LightID(provider: .homeAssistant, raw: "light.couch_lamp"),
            name: "Couch Lamp",
            capabilities: [.power, .color],
            dedupeHints: DedupeHints(uniqueID: "aaaa-bbbb", sourcePlatform: "hue")
        )
        let haOnly = Light(
            id: LightID(provider: .homeAssistant, raw: "light.tuya_strip"),
            name: "Tuya Strip",
            capabilities: [.power, .color],
            dedupeHints: DedupeHints(uniqueID: "tuya-1", sourcePlatform: "tuya")
        )

        store.setLightsForTesting([hueLight, haEcho, haOnly])

        XCTAssertEqual(store.suppressedLightIDs, [haEcho.id])
        XCTAssertEqual(Set(store.visibleLights.map(\.id)), [hueLight.id, haOnly.id])
    }

    func testNoSuppressionWithoutDirectHueConnection() {
        let store = makeStore()
        let haEcho = Light(
            id: LightID(provider: .homeAssistant, raw: "light.couch_lamp"),
            name: "Couch Lamp",
            capabilities: [.power, .color],
            dedupeHints: DedupeHints(uniqueID: "aaaa-bbbb", sourcePlatform: "hue")
        )
        store.setLightsForTesting([haEcho])
        XCTAssertTrue(store.suppressedLightIDs.isEmpty)
    }

    func testAlwaysShowOverrideWins() {
        let store = makeStore()
        let hueLight = Light(
            id: LightID(provider: .hue(bridgeID: "bridge1"), raw: "AAAA-BBBB"),
            name: "Couch Lamp",
            capabilities: [.power, .color]
        )
        let haEcho = Light(
            id: LightID(provider: .homeAssistant, raw: "light.couch_lamp"),
            name: "Couch Lamp",
            capabilities: [.power, .color],
            dedupeHints: DedupeHints(uniqueID: "aaaa-bbbb", sourcePlatform: "hue")
        )
        store.setLightsForTesting([hueLight, haEcho])
        store.dedupeOverrides.alwaysShow.insert(haEcho.id)
        XCTAssertTrue(store.suppressedLightIDs.isEmpty)
    }

    func testAlwaysHideOverride() {
        let store = makeStore()
        let light = Light(
            id: LightID(provider: .homeAssistant, raw: "light.garage"),
            name: "Garage",
            capabilities: [.power]
        )
        store.setLightsForTesting([light])
        store.dedupeOverrides.alwaysHide.insert(light.id)
        XCTAssertEqual(store.suppressedLightIDs, [light.id])
        XCTAssertTrue(store.visibleLights.isEmpty)
    }
}
