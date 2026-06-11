import Foundation

/// CIE 1931 xy chromaticity, the color space Philips Hue speaks natively.
public struct XYColor: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Color space conversions used across providers:
/// - sRGB <-> linear RGB
/// - sRGB  -> CIE 1931 xy (Hue) and back, using the Philips wide-gamut D65 matrices
/// - sRGB <-> OKLab, used for perceptually even gradient interpolation
public enum ColorMath {
    // MARK: sRGB transfer function

    public static func linearize(_ channel: Double) -> Double {
        channel > 0.04045 ? pow((channel + 0.055) / 1.055, 2.4) : channel / 12.92
    }

    public static func delinearize(_ channel: Double) -> Double {
        let clamped = min(max(channel, 0), 1)
        return clamped > 0.0031308 ? 1.055 * pow(clamped, 1 / 2.4) - 0.055 : clamped * 12.92
    }

    // MARK: Hue CIE xy

    /// sRGB -> CIE 1931 xy using the conversion Philips documents for Hue lamps.
    /// Returns the xy point plus the relative luminance Y (useful as a brightness hint).
    public static func xy(from color: PHColor) -> (point: XYColor, luminance: Double) {
        let r = linearize(color.red)
        let g = linearize(color.green)
        let b = linearize(color.blue)

        let x = r * 0.664511 + g * 0.154324 + b * 0.162028
        let y = r * 0.283881 + g * 0.668433 + b * 0.047685
        let z = r * 0.000088 + g * 0.072310 + b * 0.986039

        let sum = x + y + z
        guard sum > 0 else { return (XYColor(x: 0.3127, y: 0.3290), 0) }
        return (XYColor(x: x / sum, y: y / sum), y)
    }

    /// CIE xy + brightness (0...1) -> approximate sRGB, for previewing a lamp's color.
    public static func color(fromXY point: XYColor, brightness: Double) -> PHColor {
        let y = max(brightness, 0.0001)
        let x = (y / max(point.y, 0.0001)) * point.x
        let z = (y / max(point.y, 0.0001)) * (1 - point.x - point.y)

        var r = x * 1.656492 - y * 0.354851 - z * 0.255038
        var g = -x * 0.707196 + y * 1.655397 + z * 0.036152
        var b = x * 0.051713 - y * 0.121364 + z * 1.011530

        // Scale into displayable range before applying gamma.
        let maxComponent = max(r, g, b)
        if maxComponent > 1 {
            r /= maxComponent
            g /= maxComponent
            b /= maxComponent
        }

        return PHColor(
            red: delinearize(max(r, 0)),
            green: delinearize(max(g, 0)),
            blue: delinearize(max(b, 0))
        )
    }

    // MARK: OKLab

    public struct OKLab: Hashable, Sendable {
        public var l: Double
        public var a: Double
        public var b: Double

        public init(l: Double, a: Double, b: Double) {
            self.l = l
            self.a = a
            self.b = b
        }
    }

    public static func oklab(from color: PHColor) -> OKLab {
        let r = linearize(color.red)
        let g = linearize(color.green)
        let b = linearize(color.blue)

        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        let lc = cbrt(l)
        let mc = cbrt(m)
        let sc = cbrt(s)

        return OKLab(
            l: 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
            a: 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
            b: 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc
        )
    }

    public static func color(from lab: OKLab) -> PHColor {
        let lc = lab.l + 0.3963377774 * lab.a + 0.2158037573 * lab.b
        let mc = lab.l - 0.1055613458 * lab.a - 0.0638541728 * lab.b
        let sc = lab.l - 0.0894841775 * lab.a - 1.2914855480 * lab.b

        let l = lc * lc * lc
        let m = mc * mc * mc
        let s = sc * sc * sc

        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return PHColor(
            red: delinearize(r),
            green: delinearize(g),
            blue: delinearize(b)
        )
    }

    /// Perceptually even blend between two sRGB colors (t in 0...1).
    public static func mix(_ from: PHColor, _ to: PHColor, t: Double) -> PHColor {
        let clamped = min(max(t, 0), 1)
        let a = oklab(from: from)
        let b = oklab(from: to)
        return color(
            from: OKLab(
                l: a.l + (b.l - a.l) * clamped,
                a: a.a + (b.a - a.a) * clamped,
                b: a.b + (b.b - a.b) * clamped
            )
        )
    }

    // MARK: Color temperature

    /// Mirek (153...500) -> approximate sRGB, for previewing white-ambiance lamps.
    public static func color(fromMirek mirek: Int) -> PHColor {
        let kelvin = 1_000_000.0 / Double(min(max(mirek, 100), 600))
        return color(fromKelvin: kelvin)
    }

    /// Tanner Helland's blackbody approximation, good enough for UI previews.
    public static func color(fromKelvin kelvin: Double) -> PHColor {
        let temp = min(max(kelvin, 1000), 40000) / 100.0

        let red: Double
        if temp <= 66 {
            red = 255
        } else {
            red = 329.698727446 * pow(temp - 60, -0.1332047592)
        }

        let green: Double
        if temp <= 66 {
            green = 99.4708025861 * log(temp) - 161.1195681661
        } else {
            green = 288.1221695283 * pow(temp - 60, -0.0755148492)
        }

        let blue: Double
        if temp >= 66 {
            blue = 255
        } else if temp <= 19 {
            blue = 0
        } else {
            blue = 138.5177312231 * log(temp - 10) - 305.0447927307
        }

        return PHColor(
            red: min(max(red, 0), 255) / 255,
            green: min(max(green, 0), 255) / 255,
            blue: min(max(blue, 0), 255) / 255
        )
    }
}
