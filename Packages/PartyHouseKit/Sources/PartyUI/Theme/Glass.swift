import SwiftUI
import PartyCore

// MARK: - PHColor <-> SwiftUI bridge

public extension Color {
    init(_ phColor: PHColor) {
        self.init(.sRGB, red: phColor.red, green: phColor.green, blue: phColor.blue, opacity: 1)
    }
}

public extension PHColor {
    var swiftUIColor: Color { Color(self) }
}

// MARK: - Appearance override

/// User-selectable appearance: follow the OS, or force light/dark in-app.
public enum PartyAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public static let storageKey = "appearancePreference"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct PartyAppearanceModifier: ViewModifier {
    @AppStorage(PartyAppearance.storageKey) private var rawAppearance = PartyAppearance.system.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(PartyAppearance(rawValue: rawAppearance)?.colorScheme)
    }
}

public extension View {
    /// Applies the user's in-app light/dark override (Settings → Appearance).
    /// Attach to every scene root.
    func partyAppearance() -> some View {
        modifier(PartyAppearanceModifier())
    }
}

// MARK: - Theme

/// The app-wide type scale. Every custom surface (cards, tiles, chips, menubar)
/// draws from these five roles so sizes and weights stay consistent across
/// iPhone, iPad, and Mac. System containers (Forms, navigation titles) keep
/// their platform defaults.
public enum PartyFont {
    /// Section headers ("Party Palettes") and sheet titles.
    public static let sectionTitle = Font.system(.title3, design: .rounded, weight: .semibold)
    /// Card titles, zone names, and primary buttons.
    public static let cardTitle = Font.system(.headline, design: .rounded)
    /// Primary text inside tiles and compact rows.
    public static let label = Font.system(.subheadline, design: .rounded, weight: .medium)
    /// Captions that introduce a control ("Zone brightness").
    public static let sectionCaption = Font.system(.footnote, design: .rounded, weight: .medium)
    /// Secondary details: on-counts, percentages, chip labels.
    public static let detail = Font.system(.caption, design: .rounded)
}

public enum PartyTheme {
    public static let accent = Color(PHColor(hex: "#ff2e93")!)
    public static let accentSecondary = Color(PHColor(hex: "#7b2cbf")!)

    /// Corner radius used by all cards.
    public static let cardRadius: CGFloat = 26

    public static func paletteGradient(_ palette: Palette) -> LinearGradient {
        LinearGradient(
            stops: palette.stops.map {
                Gradient.Stop(color: Color($0.color), location: $0.position)
            },
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Liquid Glass helpers

public extension View {
    /// Standard Party House card chrome: system Liquid Glass over the content layer.
    func partyGlassCard(tint: Color? = nil) -> some View {
        glassEffect(
            tint.map { Glass.regular.tint($0.opacity(0.25)) } ?? .regular,
            in: .rect(cornerRadius: PartyTheme.cardRadius, style: .continuous)
        )
    }

    /// Pill chrome for chips that live inside scrollable rows. Avoids glassEffect
    /// (glass shapes in a scrolling container get a shared grey backdrop platter)
    /// and avoids plain materials (they read flat grey). Instead: an adaptive
    /// translucent white that matches the brightness of the glass cards.
    func partyGlassPill(tint: Color? = nil) -> some View {
        modifier(PartyPillModifier(tint: tint))
    }
}

struct PartyPillModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Capsule().fill(
                        colorScheme == .dark
                            ? Color.white.opacity(0.09)
                            : Color.white.opacity(0.62)
                    )
                    if let tint {
                        Capsule().fill(tint.opacity(0.22))
                    }
                }
            }
            .overlay(
                Capsule().strokeBorder(
                    .white.opacity(colorScheme == .dark ? 0.18 : 0.55),
                    lineWidth: 0.5
                )
            )
            .clipShape(Capsule())
    }
}

// MARK: - Background

/// The signature Party House backdrop: a deep night gradient with soft drifting
/// color glows for the glass layers to refract.
public struct PartyBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        ZStack {
            (colorScheme == .dark
                ? LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.03, blue: 0.10),
                        Color(red: 0.09, green: 0.05, blue: 0.16),
                        Color(red: 0.03, green: 0.04, blue: 0.09),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                : LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.91, blue: 0.98),
                        Color(red: 0.88, green: 0.90, blue: 0.99),
                        Color(red: 0.96, green: 0.93, blue: 0.97),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            glow(PartyTheme.accent, x: -0.32, y: -0.28, radius: 340)
            glow(PartyTheme.accentSecondary, x: 0.38, y: 0.05, radius: 380)
            glow(Color(PHColor(hex: "#00bbf9")!), x: -0.18, y: 0.42, radius: 360)
        }
        .ignoresSafeArea()
    }

    private func glow(_ color: Color, x: CGFloat, y: CGFloat, radius: CGFloat) -> some View {
        GeometryReader { proxy in
            Circle()
                .fill(color.opacity(colorScheme == .dark ? 0.22 : 0.18))
                .frame(width: radius, height: radius)
                .blur(radius: radius / 2.6)
                .position(
                    x: proxy.size.width * (0.5 + x),
                    y: proxy.size.height * (0.5 + y)
                )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shared small views

/// Horizontal gradient swatch used everywhere a palette is previewed.
public struct PaletteStrip: View {
    let palette: Palette
    var height: CGFloat

    public init(palette: Palette, height: CGFloat = 22) {
        self.palette = palette
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(PartyTheme.paletteGradient(palette))
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            )
    }
}

/// Status dot for provider connection state.
public struct ConnectionDot: View {
    let state: ProviderConnectionState

    public init(state: ProviderConnectionState) {
        self.state = state
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .accessibilityLabel(label)
    }

    private var color: Color {
        switch state {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .failed: return .red
        }
    }

    private var label: String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .failed(let message): return "Error: \(message)"
        }
    }
}

// MARK: - Environment plumbing

/// Lets PartyUI setup screens ask the app to rebuild provider connections after
/// configuration changes, without PartyUI depending on the provider modules.
public struct ReconnectAction: Sendable {
    public let run: @MainActor @Sendable () async -> Void

    public init(run: @escaping @MainActor @Sendable () async -> Void) {
        self.run = run
    }

    @MainActor
    public func callAsFunction() async {
        await run()
    }
}

public extension EnvironmentValues {
    @Entry var partyReconnect: ReconnectAction = ReconnectAction { }
}
