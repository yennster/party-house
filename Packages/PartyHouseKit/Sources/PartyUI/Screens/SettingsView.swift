import SwiftUI
import PartyCore

/// Settings: connections to each lighting system, duplicate handling, sync info.
public struct SettingsView: View {
    @Environment(LightsStore.self) private var store
    @Environment(\.partyReconnect) private var reconnect

    @State private var configs = ProviderConfigs.load()
    @State private var showingHueSetup = false
    @State private var showingHASetup = false
    @State private var showingLIFXSetup = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Connections") {
                    hueRow
                    haRow
                    lifxRow
                }

                Section {
                    NavigationLink("Other brands (Govee, WiZ, Tuya, Nanoleaf…)") {
                        OtherBrandsView()
                    }
                    NavigationLink("Control from anywhere") {
                        RemoteAccessView()
                    }
                }

                if !store.autoSuppressedLights.isEmpty || !store.dedupeOverrides.alwaysShow.isEmpty {
                    duplicatesSection
                }

                Section("iCloud Sync") {
                    Label {
                        Text("Connections, zones, and gradients sync to your other devices automatically. Secrets travel via iCloud Keychain, end-to-end encrypted.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.tint)
                    }
                }

                Section("About") {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    }
                    Link("Party House on GitHub", destination: URL(string: "https://github.com/yennster/party-house")!)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(PartyBackground())
            .navigationTitle("Settings")
            .sheet(isPresented: $showingHueSetup) {
                HueSetupView(configs: $configs)
            }
            .sheet(isPresented: $showingHASetup) {
                HASetupView(configs: $configs)
            }
            .sheet(isPresented: $showingLIFXSetup) {
                LIFXSetupView(configs: $configs)
            }
            .onChange(of: configs) {
                configs.save()
                Task { await reconnect() }
            }
        }
    }

    // MARK: Provider rows

    private var hueRow: some View {
        Button {
            showingHueSetup = true
        } label: {
            HStack {
                providerIcon("lightbulb.2.fill", color: .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Philips Hue")
                    Text(hueStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let bridge = configs.hueBridges.first,
                   let state = store.connectionStates[.hue(bridgeID: bridge.bridgeID)] {
                    ConnectionDot(state: state)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-hue")
    }

    private var hueStatus: String {
        configs.hueBridges.isEmpty
            ? "Pair with your bridge"
            : configs.hueBridges.map(\.host).joined(separator: ", ")
    }

    private var haRow: some View {
        Button {
            showingHASetup = true
        } label: {
            HStack {
                providerIcon("house.fill", color: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Home Assistant")
                    Text(configs.homeAssistant?.internalURL ?? "Connect your server")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let state = store.connectionStates[.homeAssistant] {
                    ConnectionDot(state: state)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-ha")
    }

    private var lifxRow: some View {
        Button {
            showingLIFXSetup = true
        } label: {
            HStack {
                providerIcon("rays", color: .teal)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("LIFX")
                        Text("BETA")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.teal.opacity(0.25), in: .capsule)
                    }
                    Text(configs.lifx.enabled ? "Scanning your network" : "Local network control")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let state = store.connectionStates[.lifx] {
                    ConnectionDot(state: state)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-lifx")
    }

    private func providerIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.body)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: .rect(cornerRadius: 7))
    }

    // MARK: Duplicates

    private var duplicatesSection: some View {
        Section {
            ForEach(store.autoSuppressedLights) { light in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(light.name)
                        Text("Also available via \(light.id.provider.displayName) — hidden to avoid doubles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Show") {
                        store.dedupeOverrides.alwaysShow.insert(light.id)
                        store.reconcile()
                    }
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            Text("Duplicates")
        } footer: {
            Text("Lights your Hue bridge exposes directly are hidden from Home Assistant's copy so each bulb appears once.")
        }
    }
}

/// How brands without a native integration flow in through Home Assistant.
struct OtherBrandsView: View {
    var body: some View {
        List {
            Section {
                Text("Party House controls Philips Hue and LIFX directly. Every other brand — Govee, WiZ, Tuya/Smart Life, Nanoleaf, IKEA, Matter bulbs — comes in through Home Assistant: add the brand's integration in Home Assistant, and its lights appear here automatically, ready for zones and gradients.")
                    .font(.callout)
            }
            Section("Set up in Home Assistant") {
                step("1", "In Home Assistant, open Settings → Devices & Services → Add Integration.")
                step("2", "Add your brand (e.g. “Tuya” or “Govee”) and finish its sign-in.")
                step("3", "Back in Party House, pull to refresh — the new lights show up under Home Assistant.")
            }
        }
        .navigationTitle("Other Brands")
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(PartyTheme.accent.opacity(0.3), in: .circle)
            Text(text)
                .font(.callout)
        }
    }
}

/// In-app version of Docs/RemoteAccess.md — how to reach Home Assistant from anywhere.
struct RemoteAccessView: View {
    var body: some View {
        List {
            Section {
                Text("Your Philips Hue bridge and LIFX bulbs only answer on your home network. Home Assistant is the path to controlling everything from anywhere: give it a public URL, add that URL in Party House, and the app fails over to it automatically when you leave home.")
                    .font(.callout)
            }

            Section("Easiest: Home Assistant Cloud (Nabu Casa)") {
                Text("In Home Assistant: Settings → Voice assistants & Cloud → Home Assistant Cloud. Subscribe, enable Remote Control, and copy the https://…ui.nabu.casa URL into Party House as the External URL. No router changes, TLS included.")
                    .font(.callout)
            }

            Section("Free: Cloudflare Tunnel") {
                Text("Run the Cloudflared add-on on your Home Assistant Green with your own domain. No open ports; put the resulting https URL in Party House as the External URL.")
                    .font(.callout)
            }

            Section("Your own domain / reverse proxy") {
                Text("Already serving Home Assistant at your own address (e.g. https://ha.example.com via Nginx Proxy Manager, Caddy, or a router port-forward)? Just enter that address as the External URL — if you can log into the HA dashboard there, Party House can use it. Make sure the domain is listed under http: → trusted_proxies / use_x_forwarded_for per your proxy's HA setup guide.")
                    .font(.callout)
            }

            Section("Private: Tailscale") {
                Text("Install the Tailscale add-on on the Green and the Tailscale app on this device. Use the Green's Tailscale address (e.g. http://homeassistant.tail1234.ts.net:8123) as the External URL — it works anywhere the VPN is on.")
                    .font(.callout)
            }

            Section {
                Link(
                    "Full guide with screenshots",
                    destination: URL(string: "https://github.com/yennster/party-house/blob/main/Docs/RemoteAccess.md")!
                )
            }
        }
        .navigationTitle("Control From Anywhere")
    }
}
