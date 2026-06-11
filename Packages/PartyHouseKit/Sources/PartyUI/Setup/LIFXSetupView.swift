import SwiftUI
import PartyCore

/// LIFX setup: an enable switch (it's a network scan) plus manual IPs for bulbs
/// the sweep misses. Honest about its beta status.
public struct LIFXSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var configs: ProviderConfigs

    @State private var enabled: Bool
    @State private var manualHosts: String

    public init(configs: Binding<ProviderConfigs>) {
        _configs = configs
        _enabled = State(initialValue: configs.wrappedValue.lifx.enabled)
        _manualHosts = State(initialValue: configs.wrappedValue.lifx.manualHosts.joined(separator: "\n"))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Control LIFX lights", isOn: $enabled)
                } footer: {
                    Text("Party House speaks the LIFX LAN protocol directly — no cloud account needed. Beta: this integration follows LIFX's published protocol but hasn't been verified against physical bulbs yet. If anything misbehaves, your LIFX bulbs also work via Home Assistant.")
                }

                if enabled {
                    Section {
                        TextEditor(text: $manualHosts)
                            .font(.system(.callout, design: .monospaced))
                            .frame(minHeight: 80)
                    } header: {
                        Text("Bulb IPs (optional, one per line)")
                    } footer: {
                        Text("Bulbs are found automatically by scanning your network. Add IPs here only for bulbs on another subnet.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("LIFX")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    private func save() {
        var updated = configs
        updated.lifx = LIFXConfig(
            enabled: enabled,
            manualHosts: manualHosts
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
        configs = updated
        dismiss()
    }
}
