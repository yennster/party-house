import XCTest
@testable import PartyCore

final class GradientEngineTests: XCTestCase {
    private func makeLight(_ key: String, caps: LightCapabilities) -> Light {
        Light(
            id: LightID(provider: .demo, raw: key),
            name: key,
            capabilities: caps
        )
    }

    func testSingleColorLightGetsMiddleSample() {
        let palette = Palette(name: "Test", hexColors: ["#ff0000", "#0000ff"])
        let light = makeLight("solo", caps: [.power, .color])
        let assignments = GradientEngine.assignments(palette: palette, lights: [light])

        guard case .solid(let color)? = assignments[light.id] else {
            return XCTFail("Expected a solid assignment")
        }
        let expected = palette.sample(at: 0.5)
        XCTAssertEqual(color.red, expected.red, accuracy: 0.001)
    }

    func testEndpointsGetGradientEndpoints() {
        let palette = Palette(name: "Test", hexColors: ["#ff0000", "#0000ff"])
        let lights = (0..<4).map { makeLight("l\($0)", caps: [.power, .color]) }
        let assignments = GradientEngine.assignments(palette: palette, lights: lights)

        guard case .solid(let first)? = assignments[lights.first!.id],
              case .solid(let last)? = assignments[lights.last!.id] else {
            return XCTFail("Expected solid assignments")
        }
        XCTAssertEqual(first.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(last.blue, 1.0, accuracy: 0.01)
    }

    func testNativeGradientStripGetsFivePoints() {
        let palette = Palette(name: "Test", hexColors: ["#ff0000", "#00ff00", "#0000ff"])
        let strip = makeLight("strip", caps: [.power, .color, .nativeGradient])
        let assignments = GradientEngine.assignments(palette: palette, lights: [strip])

        guard case .nativeGradient(let points)? = assignments[strip.id] else {
            return XCTFail("Expected a native gradient assignment")
        }
        XCTAssertEqual(points.count, GradientEngine.nativeGradientPointCount)
        // A lone strip spans the whole gradient.
        XCTAssertEqual(points.first!.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(points.last!.blue, 1.0, accuracy: 0.01)
    }

    func testStripInMiddleGetsItsSliceOnly() {
        let palette = Palette(name: "Test", hexColors: ["#ff0000", "#0000ff"])
        let lights = [
            makeLight("a", caps: [.power, .color]),
            makeLight("strip", caps: [.power, .color, .nativeGradient]),
            makeLight("b", caps: [.power, .color]),
        ]
        let assignments = GradientEngine.assignments(palette: palette, lights: lights)

        guard case .nativeGradient(let points)? = assignments[lights[1].id] else {
            return XCTFail("Expected a native gradient assignment")
        }
        // The middle third should not contain the pure endpoints.
        XCTAssertLessThan(points.first!.red, 0.99)
        XCTAssertLessThan(points.last!.blue, 0.99)
    }

    func testWhiteOnlyLightsGetWarmWhite() {
        let palette = Palette(name: "Test", hexColors: ["#ff0000", "#0000ff"])
        let white = makeLight("white", caps: [.power, .dimming, .colorTemperature])
        let assignments = GradientEngine.assignments(palette: palette, lights: [white])
        XCTAssertEqual(assignments[white.id], .solid(.warmWhite))
    }

    func testOrderingIsStable() {
        let palette = Palette(name: "Test", hexColors: ["#ff0000", "#0000ff"])
        let lights = (0..<10).map { makeLight("l\($0)", caps: [.power, .color]) }
        let first = GradientEngine.assignments(palette: palette, lights: lights)
        let second = GradientEngine.assignments(palette: palette, lights: lights)
        XCTAssertEqual(first, second)
    }

    func testEmptyLightsYieldsEmptyAssignments() {
        let palette = Palette(name: "Test", hexColors: ["#ff0000"])
        XCTAssertTrue(GradientEngine.assignments(palette: palette, lights: []).isEmpty)
    }
}
