import SwiftUI
import WidgetKit
import AppIntents
import PartyCore

@main
struct PartyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ZoneToggleWidget()
        HouseOffWidget()
        PaletteWidget()
    }
}

// MARK: - Shared timeline plumbing

struct ZoneSelectionIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Zone"
    static let description = IntentDescription("Pick which zone this widget controls.")

    @Parameter(title: "Zone")
    var zone: ZoneEntity?
}

struct ZoneEntry: TimelineEntry {
    let date: Date
    let zone: WidgetSnapshot.ZoneSummary?
    let totalOn: Int

    static func current(for zoneID: UUID?) -> ZoneEntry {
        let snapshot = AppGroupSnapshotStore.read()
        let zone = snapshot?.zones.first { $0.id == (zoneID ?? Zone.allLightsID) }
            ?? snapshot?.zones.first
        return ZoneEntry(date: Date(), zone: zone, totalOn: snapshot?.totalLightsOn ?? 0)
    }

    static let placeholder = ZoneEntry(
        date: Date(),
        zone: WidgetSnapshot.ZoneSummary(
            id: Zone.allLightsID,
            name: "Living Room",
            symbolName: "sofa.fill",
            lightCount: 4,
            onCount: 3,
            accentHexColors: ["#ff2e93", "#7b2cbf", "#00bbf9"]
        ),
        totalOn: 7
    )
}

struct ZoneTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ZoneEntry {
        .placeholder
    }

    func snapshot(for configuration: ZoneSelectionIntent, in context: Context) async -> ZoneEntry {
        context.isPreview ? .placeholder : .current(for: configuration.zone?.id)
    }

    func timeline(for configuration: ZoneSelectionIntent, in context: Context) async -> Timeline<ZoneEntry> {
        Timeline(
            entries: [.current(for: configuration.zone?.id)],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }
}

extension PHColor {
    /// PartyUI's Color bridge isn't linked into the widget extension; bridge locally.
    var widgetColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

extension WidgetSnapshot.ZoneSummary {
    var accentColors: [Color] {
        let parsed = accentHexColors.compactMap(PHColor.init(hex:)).map(\.widgetColor)
        return parsed.isEmpty ? [PHColor(hex: "#7b2cbf")!.widgetColor] : parsed
    }
}

// MARK: - Zone toggle widget

struct ZoneToggleWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "ZoneToggleWidget",
            intent: ZoneSelectionIntent.self,
            provider: ZoneTimelineProvider()
        ) { entry in
            ZoneToggleWidgetView(entry: entry)
        }
        .configurationDisplayName("Zone Toggle")
        .description("Turn a zone on or off with one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ZoneToggleWidgetView: View {
    let entry: ZoneEntry

    var body: some View {
        if let zone = entry.zone {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: zone.symbolName)
                        .font(.title3)
                        .foregroundStyle(
                            zone.onCount > 0
                                ? AnyShapeStyle(LinearGradient(
                                    colors: zone.accentColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                : AnyShapeStyle(.secondary)
                        )
                    Spacer()
                    Button(intent: ToggleZoneIntent(zone: ZoneEntity(id: zone.id, name: zone.name, symbolName: zone.symbolName))) {
                        Image(systemName: "power")
                            .font(.body.weight(.semibold))
                            .padding(7)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(zone.onCount > 0 ? zone.accentColors.first ?? .pink : .gray)
                    .clipShape(Circle())
                }

                Spacer()

                Text(zone.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(zone.onCount > 0 ? "\(zone.onCount) of \(zone.lightCount) on" : "All off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(for: .widget) {
                widgetBackground(colors: zone.onCount > 0 ? zone.accentColors : [])
            }
        } else {
            Text("Open Party House to set up zones")
                .font(.caption)
                .foregroundStyle(.secondary)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

// MARK: - House off widget

struct HouseOffWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "HouseOffWidget",
            provider: HouseOffProvider()
        ) { entry in
            HouseOffWidgetView(entry: entry)
        }
        .configurationDisplayName("Everything Off")
        .description("One button to end the party.")
        .supportedFamilies([.systemSmall])
    }
}

struct HouseOffProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZoneEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ZoneEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current(for: Zone.allLightsID))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZoneEntry>) -> Void) {
        completion(
            Timeline(
                entries: [.current(for: Zone.allLightsID)],
                policy: .after(Date().addingTimeInterval(15 * 60))
            )
        )
    }
}

struct HouseOffWidgetView: View {
    let entry: ZoneEntry

    var body: some View {
        VStack(spacing: 10) {
            Button(intent: AllOffIntent()) {
                Image(systemName: "power")
                    .font(.system(size: 30, weight: .bold))
                    .padding(18)
            }
            .buttonStyle(.borderedProminent)
            .tint(entry.totalOn > 0 ? .pink : .gray)
            .clipShape(Circle())

            Text(entry.totalOn > 0 ? "\(entry.totalOn) lights on" : "All quiet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Palette quick-apply widget

struct PaletteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "PaletteWidget",
            intent: ZoneSelectionIntent.self,
            provider: ZoneTimelineProvider()
        ) { entry in
            PaletteWidgetView(entry: entry)
        }
        .configurationDisplayName("Party Gradients")
        .description("Sweep a gradient across a zone with one tap.")
        .supportedFamilies([.systemMedium])
    }
}

struct PaletteWidgetView: View {
    let entry: ZoneEntry

    private var palettes: [WidgetSnapshot.PaletteSummary] {
        let snapshot = AppGroupSnapshotStore.read()
        let stored = snapshot?.palettes ?? []
        if !stored.isEmpty { return Array(stored.prefix(4)) }
        return Palette.builtIns.prefix(4).map {
            WidgetSnapshot.PaletteSummary(id: $0.id, name: $0.name, hexColors: $0.stops.map(\.color.hexString))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "rainbow")
                    .font(.caption)
                Text(entry.zone?.name ?? "All Lights")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(palettes) { palette in
                    Button(intent: ApplyPaletteIntent(
                        palette: PaletteEntity(id: palette.id, name: palette.name),
                        zone: ZoneEntity(
                            id: entry.zone?.id ?? Zone.allLightsID,
                            name: entry.zone?.name ?? "All Lights",
                            symbolName: entry.zone?.symbolName ?? "house.fill"
                        )
                    )) {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(
                                    colors: palette.hexColors.compactMap(PHColor.init(hex:)).map(\.widgetColor),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(height: 44)
                            Text(palette.name)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Helpers

@ViewBuilder
private func widgetBackground(colors: [Color]) -> some View {
    if colors.isEmpty {
        Rectangle().fill(.fill.tertiary)
    } else {
        LinearGradient(
            colors: colors.map { $0.opacity(0.28) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
