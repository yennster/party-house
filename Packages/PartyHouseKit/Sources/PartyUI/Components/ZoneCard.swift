import SwiftUI
import PartyCore

/// One zone on the Home screen: name, live on-count, a tinted glass card that picks
/// up the colors of whatever's currently glowing in that zone, and a power toggle.
public struct ZoneCard: View {
    @Environment(LightsStore.self) private var store

    let zone: Zone

    public init(zone: Zone) {
        self.zone = zone
    }

    private var members: [Light] { store.lights(in: zone) }
    private var onCount: Int { members.filter(\.state.isOn).count }
    private var accent: Color? {
        members.first(where: \.state.isOn).map { Color($0.state.displayColor) }
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: zone.symbolName)
                .font(.title2)
                .symbolVariant(.fill)
                .foregroundStyle(onCount > 0 ? AnyShapeStyle(accentGradient) : AnyShapeStyle(.secondary))
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(zone.name)
                    .font(.headline)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !members.isEmpty {
                Toggle("", isOn: powerBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(accent ?? PartyTheme.accent)
            }
        }
        .padding(16)
        .partyGlassCard(tint: onCount > 0 ? accent : nil)
        .contentShape(Rectangle())
        .accessibilityIdentifier("zone-card-\(zone.name)")
    }

    private var statusText: String {
        if members.isEmpty { return "No lights yet" }
        if onCount == 0 { return "\(members.count) lights · all off" }
        return "\(onCount) of \(members.count) on"
    }

    private var accentGradient: LinearGradient {
        let colors = members
            .filter(\.state.isOn)
            .prefix(3)
            .map { Color($0.state.displayColor) }
        return LinearGradient(
            colors: colors.isEmpty ? [PartyTheme.accent] : Array(colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var powerBinding: Binding<Bool> {
        Binding(
            get: { onCount > 0 },
            set: { newValue in
                Task { await store.setPower(newValue, lightIDs: zone.lightIDs) }
            }
        )
    }
}
