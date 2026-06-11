import SwiftUI
import PartyCore

/// One light in the zone grid. Tap toggles power; tapping the disclosure opens the
/// detail sheet with brightness + color controls.
public struct LightTile: View {
    @Environment(LightsStore.self) private var store

    let light: Light
    @State private var showingDetail = false

    public init(light: Light) {
        self.light = light
    }

    private var tint: Color? {
        light.state.isOn ? Color(light.state.displayColor) : nil
    }

    public var body: some View {
        Button {
            Task { await store.setPower(!light.state.isOn, lightIDs: [light.id]) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbolName)
                        .font(.title3)
                        .foregroundStyle(light.state.isOn ? AnyShapeStyle(Color(light.state.displayColor)) : AnyShapeStyle(.secondary))
                        .symbolVariant(.fill)

                    Spacer()

                    Button {
                        showingDetail = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(light.name) settings")
                }

                Spacer(minLength: 0)

                Text(light.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .partyGlassCard(tint: tint)
        .opacity(light.state.isReachable ? 1 : 0.45)
        .sheet(isPresented: $showingDetail) {
            LightDetailSheet(light: light)
        }
        .accessibilityIdentifier("light-tile-\(light.name)")
    }

    private var symbolName: String {
        if light.capabilities.contains(.nativeGradient) { return "light.strip.2" }
        return "lightbulb"
    }

    private var detailText: String {
        guard light.state.isOn else { return "Off" }
        let percent = Int((light.state.brightness * 100).rounded())
        if light.capabilities.contains(.nativeGradient) { return "\(percent)% · gradient" }
        return "\(percent)%"
    }
}

/// Brightness + color controls for one light.
public struct LightDetailSheet: View {
    @Environment(LightsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let light: Light
    @State private var brightness: Double
    @State private var pickedColor: Color

    public init(light: Light) {
        self.light = light
        _brightness = State(initialValue: light.state.brightness)
        _pickedColor = State(initialValue: Color(light.state.displayColor))
    }

    public var body: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 38, height: 5)
                .padding(.top, 10)

            Text(light.name)
                .font(.title3.weight(.semibold))

            if light.capabilities.contains(.dimming) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brightness — \(Int((brightness * 100).rounded()))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Slider(value: $brightness, in: 0.01...1) { editing in
                        if !editing {
                            Task { await store.setBrightness(brightness, lightIDs: [light.id]) }
                        }
                    }
                    .tint(Color(light.state.displayColor))
                }
                .padding(16)
                .partyGlassCard()
            }

            if light.capabilities.contains(.color) {
                HStack {
                    Text("Color")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ColorPicker("Light color", selection: $pickedColor, supportsOpacity: false)
                        .labelsHidden()
                }
                .padding(16)
                .partyGlassCard()
                .onChange(of: pickedColor) {
                    guard let components = pickedColor.resolve(in: .init()).cgColor.components,
                          components.count >= 3 else { return }
                    let color = PHColor(
                        red: Double(components[0]),
                        green: Double(components[1]),
                        blue: Double(components[2])
                    )
                    Task { await store.setColor(color, lightIDs: [light.id]) }
                }
            }

            Button(light.state.isOn ? "Turn Off" : "Turn On") {
                Task {
                    await store.setPower(!light.state.isOn, lightIDs: [light.id])
                    dismiss()
                }
            }
            .buttonStyle(.glassProminent)
            .tint(light.state.isOn ? .secondary : PartyTheme.accent)

            Spacer(minLength: 8)
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationBackground(.thinMaterial)
    }
}
