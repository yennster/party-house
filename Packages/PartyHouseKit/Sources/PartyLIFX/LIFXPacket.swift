import Foundation

/// Byte-level encoder/decoder for the LIFX LAN protocol (UDP port 56700).
/// Layout per https://lan.developer.lifx.com/docs/packet-contents — stable since 2015.
/// All multi-byte fields are little-endian.
enum LIFXPacket {
    static let port: UInt16 = 56700
    static let headerSize = 36

    enum MessageType: UInt16 {
        case getService = 2
        case stateService = 3
        case getColor = 101
        case setColor = 102
        case lightState = 107
        case setLightPower = 117
        case stateLightPower = 118
    }

    struct HSBK: Equatable {
        /// 0...65535 mapping to 0...360 degrees.
        var hue: UInt16
        var saturation: UInt16
        var brightness: UInt16
        /// 1500...9000 Kelvin.
        var kelvin: UInt16
    }

    // MARK: Encoding

    /// Builds a full message: 36-byte header + payload.
    ///
    /// - Parameters:
    ///   - tagged: true only for broadcast discovery (GetService).
    ///   - target: 6-byte serial, or nil to address all devices.
    static func message(
        type: MessageType,
        source: UInt32,
        sequence: UInt8,
        target: [UInt8]? = nil,
        tagged: Bool = false,
        responseRequired: Bool = true,
        payload: Data = Data()
    ) -> Data {
        var data = Data(capacity: headerSize + payload.count)

        // Frame.
        let size = UInt16(headerSize + payload.count)
        appendLE(&data, size)
        var frameFlags: UInt16 = 1024            // protocol
        frameFlags |= 1 << 12                    // addressable
        if tagged { frameFlags |= 1 << 13 }
        appendLE(&data, frameFlags)
        appendLE(&data, source)

        // Frame address.
        var targetBytes = [UInt8](repeating: 0, count: 8)
        if let target {
            for (index, byte) in target.prefix(6).enumerated() {
                targetBytes[index] = byte
            }
        }
        data.append(contentsOf: targetBytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 6)) // reserved
        data.append(responseRequired ? 0b0000_0001 : 0)          // res_required
        data.append(sequence)

        // Protocol header.
        data.append(contentsOf: [UInt8](repeating: 0, count: 8)) // reserved
        appendLE(&data, type.rawValue)
        data.append(contentsOf: [UInt8](repeating: 0, count: 2)) // reserved

        data.append(payload)
        return data
    }

    static func getService(source: UInt32, sequence: UInt8) -> Data {
        message(type: .getService, source: source, sequence: sequence, tagged: true)
    }

    static func getColor(source: UInt32, sequence: UInt8, target: [UInt8]) -> Data {
        message(type: .getColor, source: source, sequence: sequence, target: target)
    }

    /// SetColor (102): reserved u8, HSBK, duration u32 (ms).
    static func setColor(
        source: UInt32,
        sequence: UInt8,
        target: [UInt8],
        color: HSBK,
        durationMS: UInt32 = 300
    ) -> Data {
        var payload = Data()
        payload.append(0) // reserved
        appendLE(&payload, color.hue)
        appendLE(&payload, color.saturation)
        appendLE(&payload, color.brightness)
        appendLE(&payload, color.kelvin)
        appendLE(&payload, durationMS)
        return message(type: .setColor, source: source, sequence: sequence, target: target, payload: payload)
    }

    /// SetLightPower (117): level u16 (0 | 65535), duration u32 (ms).
    static func setLightPower(
        source: UInt32,
        sequence: UInt8,
        target: [UInt8],
        on: Bool,
        durationMS: UInt32 = 300
    ) -> Data {
        var payload = Data()
        appendLE(&payload, UInt16(on ? 65535 : 0))
        appendLE(&payload, durationMS)
        return message(type: .setLightPower, source: source, sequence: sequence, target: target, payload: payload)
    }

    // MARK: Decoding

    struct Header {
        let size: UInt16
        let source: UInt32
        let target: [UInt8] // 6-byte serial
        let sequence: UInt8
        let type: UInt16
    }

    static func parseHeader(_ data: Data) -> Header? {
        guard data.count >= headerSize else { return nil }
        let bytes = [UInt8](data)
        let size = readLE16(bytes, 0)
        guard Int(size) <= data.count else { return nil }
        return Header(
            size: size,
            source: readLE32(bytes, 4),
            target: Array(bytes[8..<14]),
            sequence: bytes[23],
            type: readLE16(bytes, 32)
        )
    }

    /// LightState (107): HSBK + reserved i16 + power u16 + label[32] + reserved u64.
    struct LightState {
        let color: HSBK
        let power: UInt16
        let label: String

        var isOn: Bool { power > 0 }
    }

    static func parseLightState(_ data: Data) -> LightState? {
        guard let header = parseHeader(data),
              header.type == MessageType.lightState.rawValue,
              data.count >= headerSize + 52 else { return nil }
        let bytes = [UInt8](data)
        let base = headerSize
        let color = HSBK(
            hue: readLE16(bytes, base),
            saturation: readLE16(bytes, base + 2),
            brightness: readLE16(bytes, base + 4),
            kelvin: readLE16(bytes, base + 6)
        )
        let power = readLE16(bytes, base + 10)
        let labelBytes = bytes[(base + 12)..<(base + 44)].prefix { $0 != 0 }
        let label = String(bytes: labelBytes, encoding: .utf8) ?? ""
        return LightState(color: color, power: power, label: label)
    }

    /// StateService (3): service u8, port u32.
    struct StateService {
        let serial: [UInt8]
        let service: UInt8
        let port: UInt32
    }

    static func parseStateService(_ data: Data) -> StateService? {
        guard let header = parseHeader(data),
              header.type == MessageType.stateService.rawValue,
              data.count >= headerSize + 5 else { return nil }
        let bytes = [UInt8](data)
        return StateService(
            serial: header.target,
            service: bytes[headerSize],
            port: readLE32(bytes, headerSize + 1)
        )
    }

    // MARK: Little-endian helpers

    static func appendLE(_ data: inout Data, _ value: UInt16) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8(value >> 8))
    }

    static func appendLE(_ data: inout Data, _ value: UInt32) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    static func readLE16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    static func readLE32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}
