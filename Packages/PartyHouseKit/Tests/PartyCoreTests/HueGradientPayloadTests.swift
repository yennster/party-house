import XCTest
@testable import PartyHue
@testable import PartyCore

final class HueGradientPayloadTests: XCTestCase {
    func testGradientPayloadShape() throws {
        let points = [PHColor(hex: "#ff0000")!, PHColor(hex: "#00ff00")!, PHColor(hex: "#0000ff")!]
        let payload = HuePayloads.gradient(points)

        let gradient = payload["gradient"] as? [String: Any]
        let payloadPoints = gradient?["points"] as? [[String: Any]]
        XCTAssertEqual(payloadPoints?.count, 3)

        let firstColor = payloadPoints?.first?["color"] as? [String: Any]
        let xy = firstColor?["xy"] as? [String: Any]
        XCTAssertNotNil(xy?["x"] as? Double)
        XCTAssertNotNil(xy?["y"] as? Double)

        // Must be valid JSON for the bridge.
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: payload))
    }

    func testGradientPayloadCapsAtFivePoints() {
        let points = (0..<8).map { _ in PHColor.white }
        let payload = HuePayloads.gradient(points)
        let gradient = payload["gradient"] as? [String: Any]
        let payloadPoints = gradient?["points"] as? [[String: Any]]
        XCTAssertEqual(payloadPoints?.count, 5)
    }

    func testGradientPointDecodingNestedShape() throws {
        let json = """
        {"points": [{"color": {"xy": {"x": 0.64, "y": 0.33}}}]}
        """
        let gradient = try JSONDecoder().decode(HueLightResource.Gradient.self, from: Data(json.utf8))
        XCTAssertEqual(gradient.points.first?.xy?.x, 0.64)
    }

    func testGradientPointDecodingFlatShape() throws {
        let json = """
        {"points": [{"xy": {"x": 0.2, "y": 0.7}}], "points_capable": 5}
        """
        let gradient = try JSONDecoder().decode(HueLightResource.Gradient.self, from: Data(json.utf8))
        XCTAssertEqual(gradient.points.first?.xy?.y, 0.7)
        XCTAssertEqual(gradient.pointsCapable, 5)
    }

    func testBrightnessPayloadTurnsOffAtZero() {
        let payload = HuePayloads.brightness(0)
        let on = payload["on"] as? [String: Bool]
        XCTAssertEqual(on?["on"], false)
    }

    func testColorPayloadIncludesDimming() {
        let payload = HuePayloads.color(PHColor(hex: "#ff2e93")!)
        XCTAssertNotNil(payload["color"])
        XCTAssertNotNil(payload["dimming"])
        let on = payload["on"] as? [String: Bool]
        XCTAssertEqual(on?["on"], true)
    }

    func testLightResourceDecoding() throws {
        let json = """
        {
          "errors": [],
          "data": [{
            "id": "abcd-1234",
            "owner": {"rid": "device-1", "rtype": "device"},
            "metadata": {"name": "Couch Lamp", "archetype": "table_shade"},
            "on": {"on": true},
            "dimming": {"brightness": 63.5},
            "color": {"xy": {"x": 0.5, "y": 0.4}},
            "color_temperature": {"mirek": null},
            "gradient": {"points": [], "points_capable": 5}
          }]
        }
        """
        let envelope = try JSONDecoder().decode(HueEnvelope<HueLightResource>.self, from: Data(json.utf8))
        let light = envelope.data.first
        XCTAssertEqual(light?.metadata?.name, "Couch Lamp")
        XCTAssertEqual(light?.dimming?.brightness ?? 0, 63.5, accuracy: 0.001)
        XCTAssertEqual(light?.color?.xy?.x, 0.5)
        XCTAssertNotNil(light?.gradient)
        XCTAssertNil(light?.colorTemperature?.mirek)
    }
}
