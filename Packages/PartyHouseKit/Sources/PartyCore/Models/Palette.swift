import Foundation

/// A multi-color gradient palette that can be swept across the lights of a zone.
public struct Palette: Identifiable, Hashable, Codable, Sendable {
    public struct Stop: Hashable, Codable, Sendable {
        public var color: PHColor
        /// 0...1 along the gradient.
        public var position: Double

        public init(color: PHColor, position: Double) {
            self.color = color
            self.position = min(max(position, 0), 1)
        }
    }

    public var id: UUID
    public var name: String
    public var stops: [Stop]
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, stops: [Stop], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.stops = stops.sorted { $0.position < $1.position }
        self.isBuiltIn = isBuiltIn
    }

    public init(id: UUID = UUID(), name: String, hexColors: [String], isBuiltIn: Bool = false) {
        let colors = hexColors.compactMap(PHColor.init(hex:))
        let count = max(colors.count - 1, 1)
        let stops = colors.enumerated().map { index, color in
            Stop(color: color, position: Double(index) / Double(count))
        }
        self.init(id: id, name: name, stops: stops, isBuiltIn: isBuiltIn)
    }

    /// Samples the palette at t (0...1) with perceptual (OKLab) interpolation.
    public func sample(at t: Double) -> PHColor {
        guard let first = stops.first else { return .warmWhite }
        guard stops.count > 1 else { return first.color }

        let clamped = min(max(t, 0), 1)
        if clamped <= first.position { return first.color }
        guard let last = stops.last, clamped < last.position else { return stops.last!.color }

        for index in 0..<(stops.count - 1) {
            let a = stops[index]
            let b = stops[index + 1]
            if clamped >= a.position && clamped <= b.position {
                let span = b.position - a.position
                let local = span > 0 ? (clamped - a.position) / span : 0
                return ColorMath.mix(a.color, b.color, t: local)
            }
        }
        return last.color
    }

    /// Evenly samples n colors across the palette.
    public func samples(count: Int) -> [PHColor] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [sample(at: 0.5)] }
        return (0..<count).map { sample(at: Double($0) / Double(count - 1)) }
    }
}

public extension Palette {
    /// Creates a palette from a CSS gradient string ("linear-gradient(...)" or a
    /// bare comma-separated color list).
    static func fromCSS(_ css: String, name: String) throws -> Palette {
        let parsed = try CSSGradientParser.parse(css)
        let stops = parsed.map { Stop(color: $0.color, position: $0.position ?? 0) }
        return Palette(name: name, stops: stops)
    }

    static let builtIns: [Palette] = [
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
            name: "Sunset Boulevard",
            hexColors: ["#ff6b35", "#ff2e93", "#a23ad6", "#3f37c9"],
            isBuiltIn: true
        ),
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
            name: "Neon Nights",
            hexColors: ["#00f5d4", "#00bbf9", "#9b5de5", "#f15bb5"],
            isBuiltIn: true
        ),
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000003")!,
            name: "Aurora",
            hexColors: ["#0aff99", "#16c7b2", "#3a6ee8", "#7b2cbf"],
            isBuiltIn: true
        ),
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000004")!,
            name: "Lava Lamp",
            hexColors: ["#ff0a54", "#ff5c8a", "#ff85a1", "#fbb1bd"],
            isBuiltIn: true
        ),
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000005")!,
            name: "Ocean Drive",
            hexColors: ["#03045e", "#0077b6", "#00b4d8", "#90e0ef"],
            isBuiltIn: true
        ),
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000006")!,
            name: "Golden Hour",
            hexColors: ["#ffd166", "#ffb347", "#ff8c42", "#e85d75"],
            isBuiltIn: true
        ),
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000007")!,
            name: "Candy Shop",
            hexColors: ["#ff99c8", "#fcf6bd", "#d0f4de", "#a9def9", "#e4c1f9"],
            isBuiltIn: true
        ),
        Palette(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000008")!,
            name: "Deep Space",
            hexColors: ["#10002b", "#3c096c", "#7b2cbf", "#c77dff"],
            isBuiltIn: true
        ),
    ]
}
