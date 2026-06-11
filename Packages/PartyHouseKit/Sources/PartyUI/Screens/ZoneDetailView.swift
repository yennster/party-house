import SwiftUI
import PartyCore

/// One zone: light grid, group brightness, palette quick-apply.
public struct ZoneDetailView: View {
    @Environment(LightsStore.self) private var store

    let zoneID: UUID
    @State private var groupBrightness: Double = 0.8

    public init(zoneID: UUID) {
        self.zoneID = zoneID
    }

    private var zone: Zone { store.zone(withID: zoneID) ?? store.allLightsZone }
    private var members: [Light] { store.lights(in: zone) }
    private var onCount: Int { members.filter(\.state.isOn).count }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                controlsHeader

                paletteRow

                GlassEffectContainer(spacing: 14) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(members) { light in
                            LightTile(light: light)
                        }
                    }
                }

                if members.isEmpty {
                    ContentUnavailableView(
                        "No lights in this zone",
                        systemImage: "lightbulb.slash",
                        description: Text("Edit the zone to add lights from Hue, Home Assistant, or LIFX.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(PartyBackground())
        .navigationTitle(zone.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private var controlsHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    Task { await store.setPower(true, lightIDs: zone.lightIDs) }
                } label: {
                    Label("All On", systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(PartyTheme.accent)
                .accessibilityIdentifier("zone-all-on")

                Button {
                    Task { await store.setPower(false, lightIDs: zone.lightIDs) }
                } label: {
                    Label("All Off", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("zone-all-off")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Zone brightness")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $groupBrightness, in: 0.01...1) { editing in
                    if !editing {
                        let targets = members.filter { $0.capabilities.contains(.dimming) }.map(\.id)
                        Task { await store.setBrightness(groupBrightness, lightIDs: targets) }
                    }
                }
                .tint(PartyTheme.accent)
            }
            .padding(14)
            .partyGlassCard()
        }
        .onAppear {
            let onLights = members.filter(\.state.isOn)
            if !onLights.isEmpty {
                groupBrightness = onLights.map(\.state.brightness).reduce(0, +) / Double(onLights.count)
            }
        }
    }

    private var paletteRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sweep a gradient across the zone")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(Palette.builtIns) { palette in
                            Button {
                                Task { await store.applyPalette(palette, to: zone) }
                            } label: {
                                VStack(spacing: 6) {
                                    PaletteStrip(palette: palette, height: 18)
                                        .frame(width: 92)
                                    Text(palette.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                            .partyGlassPill()
                            .accessibilityIdentifier("palette-\(palette.name)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
