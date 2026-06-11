#if os(macOS)
import SwiftUI
import AppKit
import PartyCore

/// Content of the macOS menu bar dropdown: zone picker, power, brightness, and
/// one-tap palettes — the whole party without opening the app.
public struct MenuBarContentView: View {
    @Environment(LightsStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    @State private var selectedZoneID: UUID = Zone.allLightsID
    @State private var brightness: Double = 0.8

    @AppStorage("hideDockIcon") private var hideDockIcon = false

    private var zone: Zone { store.zone(withID: selectedZoneID) ?? store.allLightsZone }
    private var members: [Light] { store.lights(in: zone) }
    private var onCount: Int { members.filter(\.state.isOn).count }

    private var hideDockIconBinding: Binding<Bool> {
        Binding(get: { hideDockIcon }, set: { hideDockIcon = $0 })
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "party.popper.fill")
                    .foregroundStyle(PartyTheme.accent)
                Text("Party House")
                    .font(.headline)
                Spacer()
                Text(onCount > 0 ? "\(onCount) on" : "All off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Zone", selection: $selectedZoneID) {
                ForEach(store.displayZones) { zone in
                    Text(zone.name).tag(zone.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            HStack(spacing: 10) {
                Button {
                    Task { await store.setPower(true, lightIDs: zone.lightIDs) }
                } label: {
                    Label("On", systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(PartyTheme.accent)

                Button {
                    Task { await store.setPower(false, lightIDs: zone.lightIDs) }
                } label: {
                    Label("Off", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Brightness")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $brightness, in: 0.01...1) { editing in
                    if !editing {
                        let targets = members.filter { $0.capabilities.contains(.dimming) }.map(\.id)
                        Task { await store.setBrightness(brightness, lightIDs: targets) }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Gradients")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Palette.builtIns.prefix(6)) { palette in
                            Button {
                                Task { await store.applyPalette(palette, to: zone) }
                            } label: {
                                PaletteStrip(palette: palette, height: 16)
                                    .frame(width: 72)
                            }
                            .buttonStyle(.plain)
                            .help(palette.name)
                        }
                    }
                }
            }

            Divider()

            Toggle("Hide Dock icon", isOn: hideDockIconBinding)
                .font(.callout)
                .toggleStyle(.checkbox)

            HStack {
                Button("Open Party House") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.callout)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
#endif
