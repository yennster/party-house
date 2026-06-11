import Foundation

/// Maps a palette onto a list of lights: each light gets a single color sampled at
/// its position along the zone, except native gradient strips, which receive a
/// multi-point slice of the span they occupy so the gradient flows *through* them.
public enum GradientEngine {
    public enum Assignment: Equatable, Sendable {
        case solid(PHColor)
        case nativeGradient([PHColor])
    }

    /// Number of points sent to native gradient strips (Hue supports 2...5).
    public static let nativeGradientPointCount = 5

    public static func assignments(palette: Palette, lights: [Light]) -> [LightID: Assignment] {
        var result: [LightID: Assignment] = [:]
        let count = lights.count
        guard count > 0 else { return result }

        for (index, light) in lights.enumerated() {
            // The span of the overall gradient this light occupies.
            let start = Double(index) / Double(count)
            let end = Double(index + 1) / Double(count)
            let center = count == 1 ? 0.5 : Double(index) / Double(max(count - 1, 1))

            if light.capabilities.contains(.nativeGradient) {
                let points = (0..<nativeGradientPointCount).map { p -> PHColor in
                    let t = start + (end - start) * Double(p) / Double(nativeGradientPointCount - 1)
                    return palette.sample(at: t)
                }
                result[light.id] = .nativeGradient(points)
            } else if light.capabilities.contains(.color) {
                result[light.id] = .solid(palette.sample(at: center))
            } else {
                // White-only lights join the party at full warmth instead of being
                // left out — callers may choose to skip them instead.
                result[light.id] = .solid(.warmWhite)
            }
        }
        return result
    }
}
