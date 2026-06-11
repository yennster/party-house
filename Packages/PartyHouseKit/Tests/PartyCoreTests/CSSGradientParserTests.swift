import XCTest
@testable import PartyCore

final class CSSGradientParserTests: XCTestCase {
    func testLinearGradientWithHexAndPositions() throws {
        let stops = try CSSGradientParser.parse("linear-gradient(45deg, #ff0000 0%, #00ff00 50%, #0000ff 100%)")
        XCTAssertEqual(stops.count, 3)
        XCTAssertEqual(stops[0].color, PHColor(hex: "#ff0000"))
        XCTAssertEqual(stops[1].position, 0.5)
        XCTAssertEqual(stops[2].color, PHColor(hex: "#0000ff"))
    }

    func testDirectionArgumentsAreSkipped() throws {
        XCTAssertEqual(try CSSGradientParser.parse("linear-gradient(to right, red, blue)").count, 2)
        XCTAssertEqual(try CSSGradientParser.parse("radial-gradient(circle, red, blue)").count, 2)
        XCTAssertEqual(try CSSGradientParser.parse("conic-gradient(from 90deg, red, blue)").count, 2)
        XCTAssertEqual(try CSSGradientParser.parse("radial-gradient(circle at center, red, blue)").count, 2)
    }

    func testRGBFunctions() throws {
        let stops = try CSSGradientParser.parse("linear-gradient(90deg, rgb(255, 0, 128), rgba(0, 200, 255, 0.5))")
        XCTAssertEqual(stops.count, 2)
        XCTAssertEqual(stops[0].color.rgb255.red, 255)
        XCTAssertEqual(stops[0].color.rgb255.blue, 128)
        XCTAssertEqual(stops[1].color.rgb255.green, 200)
    }

    func testNamedColors() throws {
        let stops = try CSSGradientParser.parse("linear-gradient(hotpink, rebeccapurple, dodgerblue)")
        XCTAssertEqual(stops.count, 3)
        XCTAssertEqual(stops[0].color, PHColor(hex: "#ff69b4"))
        XCTAssertEqual(stops[1].color, PHColor(hex: "#663399"))
    }

    func testBareCommaList() throws {
        let stops = try CSSGradientParser.parse("#ff0080, #7928ca, #4400ff")
        XCTAssertEqual(stops.count, 3)
        XCTAssertEqual(stops[0].position, 0)
        XCTAssertEqual(stops[1].position!, 0.5, accuracy: 0.0001)
        XCTAssertEqual(stops[2].position, 1)
    }

    func testImplicitPositionsAreEvenlyDistributed() throws {
        let stops = try CSSGradientParser.parse("linear-gradient(red, green, blue, yellow)")
        let positions = stops.compactMap(\.position)
        XCTAssertEqual(positions, [0, 1.0 / 3.0, 2.0 / 3.0, 1.0].map { $0 }, accuracy: 0.0001)
    }

    func testPartialPositionsInterpolate() throws {
        let stops = try CSSGradientParser.parse("linear-gradient(red 20%, green, blue 80%)")
        XCTAssertEqual(stops[0].position!, 0.2, accuracy: 0.0001)
        XCTAssertEqual(stops[1].position!, 0.5, accuracy: 0.0001)
        XCTAssertEqual(stops[2].position!, 0.8, accuracy: 0.0001)
    }

    func testBackwardsPositionsAreClamped() throws {
        let stops = try CSSGradientParser.parse("linear-gradient(red 60%, green 30%, blue)")
        let positions = stops.compactMap(\.position)
        XCTAssertEqual(positions[0], 0.6, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(positions[1], positions[0])
        XCTAssertGreaterThanOrEqual(positions[2], positions[1])
    }

    func testInvalidInputThrows() {
        XCTAssertThrowsError(try CSSGradientParser.parse(""))
        XCTAssertThrowsError(try CSSGradientParser.parse("linear-gradient(notacolor, alsonot)"))
    }

    func testPaletteFromCSS() throws {
        let palette = try Palette.fromCSS("linear-gradient(90deg, #ff0080, #4400ff)", name: "Test")
        XCTAssertEqual(palette.stops.count, 2)
        XCTAssertEqual(palette.name, "Test")
        XCTAssertFalse(palette.isBuiltIn)
    }
}

private func XCTAssertEqual(_ lhs: [Double], _ rhs: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
    for (a, b) in zip(lhs, rhs) {
        XCTAssertEqual(a, b, accuracy: accuracy, file: file, line: line)
    }
}
