import XCTest
@testable import PartyCore

final class ModelCodableTests: XCTestCase {
    func testLightRoundTrip() throws {
        let light = Light(
            id: LightID(provider: .hue(bridgeID: "abc123"), raw: "uuid-1"),
            name: "Couch Lamp",
            room: "Living Room",
            capabilities: [.power, .dimming, .color],
            state: LightState(isOn: true, brightness: 0.5, color: PHColor(hex: "#ff2e93")),
            dedupeHints: DedupeHints(uniqueID: "uuid-1", sourcePlatform: "hue")
        )
        let data = try JSONEncoder().encode(light)
        let decoded = try JSONDecoder().decode(Light.self, from: data)
        XCTAssertEqual(decoded, light)
    }

    func testZoneRoundTrip() throws {
        let zone = Zone(
            name: "Party Floor",
            symbolName: "party.popper.fill",
            lightIDs: [
                LightID(provider: .hue(bridgeID: "abc"), raw: "1"),
                LightID(provider: .homeAssistant, raw: "light.kitchen"),
                LightID(provider: .lifx, raw: "d073d5123456"),
            ]
        )
        let data = try JSONEncoder().encode(zone)
        let decoded = try JSONDecoder().decode(Zone.self, from: data)
        XCTAssertEqual(decoded, zone)
    }

    func testPaletteRoundTripAndSampling() throws {
        let palette = Palette.builtIns[0]
        let data = try JSONEncoder().encode(palette)
        let decoded = try JSONDecoder().decode(Palette.self, from: data)
        XCTAssertEqual(decoded, palette)

        let samples = decoded.samples(count: 5)
        XCTAssertEqual(samples.count, 5)
        XCTAssertEqual(samples.first, decoded.stops.first?.color)
    }

    func testProviderConfigsRoundTrip() throws {
        let configs = ProviderConfigs(
            hueBridges: [HueBridgeConfig(bridgeID: "ecb5fa000000", host: "192.168.1.2")],
            homeAssistant: HomeAssistantConfig(
                internalURL: "http://homeassistant.local:8123",
                externalURL: "https://example.ui.nabu.casa"
            ),
            lifx: LIFXConfig(enabled: true, manualHosts: ["192.168.1.30"])
        )
        let data = try JSONEncoder().encode(configs)
        let decoded = try JSONDecoder().decode(ProviderConfigs.self, from: data)
        XCTAssertEqual(decoded, configs)
    }

    func testAllLightsZoneIsStable() {
        let a = Zone.allLights(with: [])
        let b = Zone.allLights(with: [LightID(provider: .demo, raw: "x")])
        XCTAssertEqual(a.id, b.id)
        XCTAssertTrue(a.isAllLights)
    }
}

extension ModelCodableTests {
    func testHAURLNormalization() {
        // Bare public hostname gets https.
        XCTAssertEqual(HomeAssistantConfig.normalized("ha.speelman.casa"), "https://ha.speelman.casa")
        // Bare .local / IP / localhost get http (no certs on LAN).
        XCTAssertEqual(HomeAssistantConfig.normalized("homeassistant.local:8123"), "http://homeassistant.local:8123")
        XCTAssertEqual(HomeAssistantConfig.normalized("192.168.1.5:8123"), "http://192.168.1.5:8123")
        XCTAssertEqual(HomeAssistantConfig.normalized("localhost:8123"), "http://localhost:8123")
        // Explicit schemes are preserved.
        XCTAssertEqual(HomeAssistantConfig.normalized("http://ha.example.com"), "http://ha.example.com")
        XCTAssertEqual(HomeAssistantConfig.normalized("https://x.ui.nabu.casa/"), "https://x.ui.nabu.casa")
        // Whitespace and trailing slashes are stripped.
        XCTAssertEqual(HomeAssistantConfig.normalized("  https://ha.example.com//  "), "https://ha.example.com")
        XCTAssertEqual(HomeAssistantConfig.normalized("   "), "")
    }
}
