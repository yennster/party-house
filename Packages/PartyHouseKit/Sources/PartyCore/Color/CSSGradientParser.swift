import Foundation

/// Parses CSS gradient strings into color stops so palettes can be pasted straight
/// from design tools or sites like cssgradient.io.
///
/// Accepted inputs:
///   linear-gradient(45deg, #ff0080 0%, rgb(0, 200, 255) 60%, blue)
///   radial-gradient(circle, #f00, #00f)
///   conic-gradient(from 90deg, red, orange, yellow)
///   "#ff0080, #7928ca, #4400ff"            (a bare comma list also works)
public enum CSSGradientParser {
    public struct Stop: Equatable, Sendable {
        public var color: PHColor
        /// 0...1 if the input specified a position, nil otherwise.
        public var position: Double?

        public init(color: PHColor, position: Double? = nil) {
            self.color = color
            self.position = position
        }
    }

    public enum ParseError: Error, Equatable {
        case empty
        case noColorsFound
        case invalidColor(String)
    }

    /// Parses the gradient and returns stops with all positions resolved (evenly
    /// distributed where the input left them implicit, matching CSS behavior).
    public static func parse(_ input: String) throws -> [Stop] {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ParseError.empty }

        // Unwrap `xxx-gradient( ... )`.
        let lowered = text.lowercased()
        for kind in ["linear-gradient", "radial-gradient", "conic-gradient", "repeating-linear-gradient", "repeating-radial-gradient"] {
            if lowered.hasPrefix(kind) {
                guard let open = text.firstIndex(of: "("), let close = text.lastIndex(of: ")") , open < close else {
                    throw ParseError.noColorsFound
                }
                text = String(text[text.index(after: open)..<close])
                break
            }
        }

        var stops: [Stop] = []
        for argument in splitTopLevel(text) {
            if let stop = try parseStopArgument(argument) {
                stops.append(stop)
            }
        }

        guard stops.count >= 1 else { throw ParseError.noColorsFound }
        return resolvingPositions(stops)
    }

    // MARK: - Pieces

    /// Splits on commas that are not nested inside parentheses.
    static func splitTopLevel(_ text: String) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for char in text {
            switch char {
            case "(": depth += 1; current.append(char)
            case ")": depth -= 1; current.append(char)
            case "," where depth == 0:
                parts.append(current)
                current = ""
            default:
                current.append(char)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(current)
        }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Parses one comma-separated argument; returns nil for direction/shape
    /// arguments like "45deg", "to right", "circle", "from 90deg", "at center".
    static func parseStopArgument(_ argument: String) throws -> Stop? {
        let trimmed = argument.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        if isDirectionArgument(lowered) { return nil }

        // Split off a trailing position: "<color> 35%" / "<color> 0.35".
        var colorText = trimmed
        var position: Double?
        if let lastSpace = trimmed.range(of: " ", options: .backwards),
           !trimmed.hasSuffix(")") || trimmed[lastSpace.upperBound...].contains("%") {
            let tail = trimmed[lastSpace.upperBound...].trimmingCharacters(in: .whitespaces)
            if let parsed = parsePosition(tail) {
                position = parsed
                colorText = String(trimmed[..<lastSpace.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }

        guard let color = parseColor(colorText) else {
            throw ParseError.invalidColor(colorText)
        }
        return Stop(color: color, position: position)
    }

    static func isDirectionArgument(_ lowered: String) -> Bool {
        if lowered.hasPrefix("to ") || lowered.hasPrefix("from ") || lowered.hasPrefix("at ") { return true }
        if lowered.hasSuffix("deg") || lowered.hasSuffix("turn") || lowered.hasSuffix("rad") || lowered.hasSuffix("grad") {
            let head = lowered.dropLast(while: { $0.isLetter })
            if Double(head.trimmingCharacters(in: .whitespaces)) != nil { return true }
        }
        if ["circle", "ellipse", "closest-side", "closest-corner", "farthest-side", "farthest-corner"].contains(where: { lowered.hasPrefix($0) }) {
            return true
        }
        return false
    }

    static func parsePosition(_ text: String) -> Double? {
        if text.hasSuffix("%"), let value = Double(text.dropLast()) {
            return value / 100.0
        }
        if let value = Double(text), value >= 0, value <= 1 {
            return value
        }
        return nil
    }

    public static func parseColor(_ text: String) -> PHColor? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        if lowered.hasPrefix("#") {
            return PHColor(hex: lowered)
        }

        if lowered.hasPrefix("rgb") {
            guard let open = lowered.firstIndex(of: "("), let close = lowered.lastIndex(of: ")"), open < close else { return nil }
            let body = lowered[lowered.index(after: open)..<close]
            let separators = CharacterSet(charactersIn: ", /")
            let parts = body.components(separatedBy: separators).filter { !$0.isEmpty }
            guard parts.count >= 3 else { return nil }

            func channel(_ raw: String) -> Double? {
                if raw.hasSuffix("%"), let value = Double(raw.dropLast()) { return value / 100.0 }
                if let value = Double(raw) { return value / 255.0 }
                return nil
            }

            guard let r = channel(parts[0]), let g = channel(parts[1]), let b = channel(parts[2]) else { return nil }
            return PHColor(red: r, green: g, blue: b)
        }

        if let named = namedColors[lowered] {
            return PHColor(hex: named)
        }

        // Bare hex without "#".
        if lowered.count == 6, lowered.allSatisfy({ $0.isHexDigit }) {
            return PHColor(hex: lowered)
        }

        return nil
    }

    /// Resolves nil positions the way CSS does: first stop 0, last stop 1,
    /// unpositioned middle stops spread evenly between their positioned neighbors.
    static func resolvingPositions(_ stops: [Stop]) -> [Stop] {
        guard !stops.isEmpty else { return stops }
        var resolved = stops

        if resolved[0].position == nil { resolved[0].position = 0 }
        if resolved[resolved.count - 1].position == nil { resolved[resolved.count - 1].position = 1 }

        var index = 0
        while index < resolved.count {
            if resolved[index].position == nil {
                var end = index
                while end < resolved.count, resolved[end].position == nil { end += 1 }
                let startValue = resolved[index - 1].position ?? 0
                let endValue = resolved[end].position ?? 1
                let gap = end - index + 1
                for offset in 0..<(end - index) {
                    resolved[index + offset].position = startValue + (endValue - startValue) * Double(offset + 1) / Double(gap)
                }
                index = end
            } else {
                index += 1
            }
        }

        // Positions must be monotonically non-decreasing (CSS clamps backwards stops).
        var running = 0.0
        for i in resolved.indices {
            let value = max(resolved[i].position ?? 0, running)
            resolved[i].position = min(value, 1)
            running = value
        }
        return resolved
    }

    static let namedColors: [String: String] = [
        "black": "#000000", "white": "#ffffff", "red": "#ff0000", "lime": "#00ff00",
        "blue": "#0000ff", "yellow": "#ffff00", "cyan": "#00ffff", "aqua": "#00ffff",
        "magenta": "#ff00ff", "fuchsia": "#ff00ff", "green": "#008000", "orange": "#ffa500",
        "purple": "#800080", "pink": "#ffc0cb", "hotpink": "#ff69b4", "deeppink": "#ff1493",
        "coral": "#ff7f50", "tomato": "#ff6347", "orangered": "#ff4500", "gold": "#ffd700",
        "violet": "#ee82ee", "indigo": "#4b0082", "navy": "#000080", "teal": "#008080",
        "turquoise": "#40e0d0", "skyblue": "#87ceeb", "deepskyblue": "#00bfff",
        "dodgerblue": "#1e90ff", "royalblue": "#4169e1", "slateblue": "#6a5acd",
        "mediumpurple": "#9370db", "orchid": "#da70d6", "plum": "#dda0dd",
        "salmon": "#fa8072", "crimson": "#dc143c", "firebrick": "#b22222",
        "maroon": "#800000", "olive": "#808000", "chartreuse": "#7fff00",
        "springgreen": "#00ff7f", "seagreen": "#2e8b57", "forestgreen": "#228b22",
        "limegreen": "#32cd32", "lavender": "#e6e6fa", "thistle": "#d8bfd8",
        "ivory": "#fffff0", "beige": "#f5f5dc", "tan": "#d2b48c", "chocolate": "#d2691e",
        "brown": "#a52a2a", "gray": "#808080", "grey": "#808080", "silver": "#c0c0c0",
        "gainsboro": "#dcdcdc", "rebeccapurple": "#663399", "goldenrod": "#daa520",
        "khaki": "#f0e68c", "peachpuff": "#ffdab9", "mistyrose": "#ffe4e1",
        "aquamarine": "#7fffd4", "mediumspringgreen": "#00fa9a", "steelblue": "#4682b4",
        "cornflowerblue": "#6495ed", "lightblue": "#add8e6", "powderblue": "#b0e0e6",
        "midnightblue": "#191970", "darkblue": "#00008b", "mediumblue": "#0000cd",
        "darkviolet": "#9400d3", "darkorchid": "#9932cc", "blueviolet": "#8a2be2",
        "mediumvioletred": "#c71585", "palevioletred": "#db7093",
    ]
}

private extension StringProtocol {
    func dropLast(while predicate: (Character) -> Bool) -> SubSequence {
        var view = self[...]
        while let last = view.last, predicate(last) {
            view = view.dropLast()
        }
        return view
    }
}
