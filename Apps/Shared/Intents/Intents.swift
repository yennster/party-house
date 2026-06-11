import AppIntents
import Foundation
import PartyCore
import WidgetKit

/// Toggle every light in a zone — any light on means "turn it all off".
struct ToggleZoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Zone"
    static let description = IntentDescription("Turn all lights in a Party House zone on or off.")

    @Parameter(title: "Zone")
    var zone: ZoneEntity

    init() {}

    init(zone: ZoneEntity) {
        self.zone = zone
    }

    func perform() async throws -> some IntentResult {
        try await ActionRunner().toggleZone(zone.id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// The big red button: every light in the house, off.
struct AllOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Everything Off"
    static let description = IntentDescription("Turn off every light Party House knows about.")

    init() {}

    func perform() async throws -> some IntentResult {
        let runner = ActionRunner()
        if let zone = runner.zone(withID: Zone.allLightsID) {
            try await runner.setPower(false, zone: zone)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Sweep a gradient palette across a zone.
struct ApplyPaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Gradient"
    static let description = IntentDescription("Sweep a gradient across a Party House zone.")

    @Parameter(title: "Gradient")
    var palette: PaletteEntity

    @Parameter(title: "Zone")
    var zone: ZoneEntity

    init() {}

    init(palette: PaletteEntity, zone: ZoneEntity) {
        self.palette = palette
        self.zone = zone
    }

    func perform() async throws -> some IntentResult {
        try await ActionRunner().applyPalette(palette.id, zoneID: zone.id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
