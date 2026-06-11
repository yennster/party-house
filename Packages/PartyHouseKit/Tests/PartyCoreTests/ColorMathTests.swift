import XCTest
@testable import PartyCore

final class ColorMathTests: XCTestCase {
    func testWhitePointXY() {
        let (point, luminance) = ColorMath.xy(from: .white)
        // Philips wide-gamut conversion puts pure white near D65.
        XCTAssertEqual(point.x, 0.3227, accuracy: 0.005)
        XCTAssertEqual(point.y, 0.3290, accuracy: 0.005)
        XCTAssertEqual(luminance, 1.0, accuracy: 0.01)
    }

    func testPrimaryRedXY() {
        let (point, _) = ColorMath.xy(from: PHColor(red: 1, green: 0, blue: 0))
        XCTAssertEqual(point.x, 0.7006, accuracy: 0.005)
        XCTAssertEqual(point.y, 0.2993, accuracy: 0.005)
    }

    func testBlackFallsBackToD65() {
        let (point, luminance) = ColorMath.xy(from: .black)
        XCTAssertEqual(point.x, 0.3127, accuracy: 0.0001)
        XCTAssertEqual(point.y, 0.3290, accuracy: 0.0001)
        XCTAssertEqual(luminance, 0)
    }

    func testXYRoundTripStaysClose() {
        let original = PHColor(hex: "#ff2e93")!
        let (point, luminance) = ColorMath.xy(from: original)
        let restored = ColorMath.color(fromXY: point, brightness: luminance)
        let (restoredPoint, _) = ColorMath.xy(from: restored)
        XCTAssertEqual(restoredPoint.x, point.x, accuracy: 0.02)
        XCTAssertEqual(restoredPoint.y, point.y, accuracy: 0.02)
    }

    func testOKLabWhiteIsNeutral() {
        let lab = ColorMath.oklab(from: .white)
        XCTAssertEqual(lab.l, 1.0, accuracy: 0.001)
        XCTAssertEqual(lab.a, 0.0, accuracy: 0.001)
        XCTAssertEqual(lab.b, 0.0, accuracy: 0.001)
    }

    func testOKLabRoundTrip() {
        for hex in ["#ff0000", "#00ff00", "#0000ff", "#ff2e93", "#7b2cbf", "#90e0ef"] {
            let original = PHColor(hex: hex)!
            let restored = ColorMath.color(from: ColorMath.oklab(from: original))
            XCTAssertEqual(restored.red, original.red, accuracy: 0.002, "red of \(hex)")
            XCTAssertEqual(restored.green, original.green, accuracy: 0.002, "green of \(hex)")
            XCTAssertEqual(restored.blue, original.blue, accuracy: 0.002, "blue of \(hex)")
        }
    }

    func testMixEndpointsAreIdentity() {
        let a = PHColor(hex: "#ff6b35")!
        let b = PHColor(hex: "#3f37c9")!
        let atStart = ColorMath.mix(a, b, t: 0)
        let atEnd = ColorMath.mix(a, b, t: 1)
        XCTAssertEqual(atStart.red, a.red, accuracy: 0.002)
        XCTAssertEqual(atEnd.blue, b.blue, accuracy: 0.002)
    }

    func testHexParsing() {
        XCTAssertEqual(PHColor(hex: "#ff0000")!.rgb255.red, 255)
        XCTAssertEqual(PHColor(hex: "f00")!.rgb255.red, 255)
        XCTAssertEqual(PHColor(hex: "#ff000080")!.rgb255.red, 255) // alpha ignored
        XCTAssertNil(PHColor(hex: "#zzz"))
        XCTAssertNil(PHColor(hex: "#ff00"))
        XCTAssertEqual(PHColor(hex: "#1e90ff")!.hexString, "#1e90ff")
    }

    func testMirekPreviewIsWarm() {
        let warm = ColorMath.color(fromMirek: 400) // 2500 K
        let cool = ColorMath.color(fromMirek: 153) // 6500 K
        XCTAssertGreaterThan(warm.red, warm.blue)
        XCTAssertEqual(cool.red, cool.blue, accuracy: 0.15)
    }
}
