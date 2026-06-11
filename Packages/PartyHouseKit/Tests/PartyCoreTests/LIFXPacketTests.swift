import XCTest
@testable import PartyLIFX
@testable import PartyCore

final class LIFXPacketTests: XCTestCase {
    func testGetServiceBroadcastBytes() {
        // Reference frame from the LIFX LAN docs "building a device::GetService packet":
        // size 36, protocol 1024 | addressable | tagged, type 2.
        let packet = LIFXPacket.getService(source: 0x12345678, sequence: 0)
        let bytes = [UInt8](packet)

        XCTAssertEqual(bytes.count, 36)
        XCTAssertEqual(bytes[0], 36) // size LE low byte
        XCTAssertEqual(bytes[1], 0)
        XCTAssertEqual(bytes[2], 0x00) // 0x3400 LE: protocol 1024 + addressable + tagged
        XCTAssertEqual(bytes[3], 0x34)
        XCTAssertEqual(Array(bytes[4..<8]), [0x78, 0x56, 0x34, 0x12]) // source LE
        XCTAssertEqual(Array(bytes[8..<16]), [UInt8](repeating: 0, count: 8)) // broadcast target
        XCTAssertEqual(bytes[32], 2) // type GetService
        XCTAssertEqual(bytes[33], 0)
    }

    func testSetColorPayloadLayout() {
        let target: [UInt8] = [0xd0, 0x73, 0xd5, 0x12, 0x34, 0x56]
        let color = LIFXPacket.HSBK(hue: 21845, saturation: 65535, brightness: 65535, kelvin: 3500)
        let packet = LIFXPacket.setColor(source: 1, sequence: 7, target: target, color: color, durationMS: 1024)
        let bytes = [UInt8](packet)

        XCTAssertEqual(bytes.count, 36 + 13)
        XCTAssertEqual(bytes[0], 49) // total size
        XCTAssertEqual(bytes[2], 0x00) // not tagged: 0x1400 LE
        XCTAssertEqual(bytes[3], 0x14)
        XCTAssertEqual(Array(bytes[8..<14]), target)
        XCTAssertEqual(bytes[23], 7) // sequence
        XCTAssertEqual(bytes[32], 102) // SetColor

        // Payload: reserved u8, hue u16, sat u16, bri u16, kelvin u16, duration u32.
        XCTAssertEqual(bytes[36], 0)
        XCTAssertEqual(LIFXPacket.readLE16(bytes, 37), 21845)
        XCTAssertEqual(LIFXPacket.readLE16(bytes, 39), 65535)
        XCTAssertEqual(LIFXPacket.readLE16(bytes, 41), 65535)
        XCTAssertEqual(LIFXPacket.readLE16(bytes, 43), 3500)
        XCTAssertEqual(LIFXPacket.readLE32(bytes, 45), 1024)
    }

    func testSetLightPowerPayload() {
        let target: [UInt8] = [1, 2, 3, 4, 5, 6]
        let packet = LIFXPacket.setLightPower(source: 1, sequence: 1, target: target, on: true, durationMS: 300)
        let bytes = [UInt8](packet)

        XCTAssertEqual(bytes.count, 36 + 6)
        XCTAssertEqual(bytes[32], 117)
        XCTAssertEqual(LIFXPacket.readLE16(bytes, 36), 65535)
        XCTAssertEqual(LIFXPacket.readLE32(bytes, 38), 300)
    }

    func testLightStateRoundTrip() {
        // Build a LightState (107) reply by hand and parse it back.
        var payload = Data()
        LIFXPacket.appendLE(&payload, UInt16(5000))   // hue
        LIFXPacket.appendLE(&payload, UInt16(60000))  // saturation
        LIFXPacket.appendLE(&payload, UInt16(30000))  // brightness
        LIFXPacket.appendLE(&payload, UInt16(3500))   // kelvin
        LIFXPacket.appendLE(&payload, UInt16(0))      // reserved
        LIFXPacket.appendLE(&payload, UInt16(65535))  // power
        var label = Array("Desk Lamp".utf8)
        label.append(contentsOf: [UInt8](repeating: 0, count: 32 - label.count))
        payload.append(contentsOf: label)
        payload.append(contentsOf: [UInt8](repeating: 0, count: 8)) // reserved

        let message = LIFXPacket.message(
            type: .lightState,
            source: 99,
            sequence: 3,
            target: [1, 2, 3, 4, 5, 6],
            payload: payload
        )

        let state = LIFXPacket.parseLightState(message)
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.label, "Desk Lamp")
        XCTAssertTrue(state?.isOn ?? false)
        XCTAssertEqual(state?.color.hue, 5000)
        XCTAssertEqual(state?.color.brightness, 30000)
    }

    func testStateServiceParsing() {
        var payload = Data()
        payload.append(1) // service UDP
        LIFXPacket.appendLE(&payload, UInt32(56700))

        let message = LIFXPacket.message(
            type: .stateService,
            source: 1,
            sequence: 1,
            target: [0xd0, 0x73, 0xd5, 0xaa, 0xbb, 0xcc],
            payload: payload
        )

        let service = LIFXPacket.parseStateService(message)
        XCTAssertEqual(service?.service, 1)
        XCTAssertEqual(service?.port, 56700)
        XCTAssertEqual(service?.serial, [0xd0, 0x73, 0xd5, 0xaa, 0xbb, 0xcc])
    }

    func testHSBKConversionRoundTrip() {
        let original = PHColor(hex: "#ff2e93")!
        let hsbk = LIFXProvider.hsbk(from: original)
        let restored = LIFXProvider.color(from: hsbk)
        XCTAssertEqual(restored.red, original.red, accuracy: 0.02)
        XCTAssertEqual(restored.green, original.green, accuracy: 0.02)
        XCTAssertEqual(restored.blue, original.blue, accuracy: 0.02)
    }
}
