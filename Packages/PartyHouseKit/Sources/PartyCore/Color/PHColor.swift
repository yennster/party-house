import Foundation

/// A plain sRGB color value (components 0...1), independent of SwiftUI/AppKit/UIKit.
public struct PHColor: Hashable, Codable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    public init(red255: Int, green255: Int, blue255: Int) {
        self.init(
            red: Double(red255) / 255.0,
            green: Double(green255) / 255.0,
            blue: Double(blue255) / 255.0
        )
    }

    /// Parses "#rgb", "#rrggbb" or "#rrggbbaa" (alpha ignored). Leading "#" optional.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.allSatisfy({ $0.isHexDigit }) else { return nil }

        switch text.count {
        case 3:
            let chars = Array(text)
            text = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
        case 6, 8:
            break
        default:
            return nil
        }

        guard let value = UInt64(text.prefix(6), radix: 16) else { return nil }
        self.init(
            red255: Int((value >> 16) & 0xff),
            green255: Int((value >> 8) & 0xff),
            blue255: Int(value & 0xff)
        )
    }

    public var hexString: String {
        String(
            format: "#%02x%02x%02x",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    public var rgb255: (red: Int, green: Int, blue: Int) {
        (Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    public static let white = PHColor(red: 1, green: 1, blue: 1)
    public static let black = PHColor(red: 0, green: 0, blue: 0)
    /// Warm white, roughly 2700 K.
    public static let warmWhite = PHColor(red: 1.0, green: 0.82, blue: 0.64)
}
