import SwiftUI
import PartyCore
import PartyHue

/// Hue onboarding: find the bridge (mDNS/cloud or manual IP), press the link
/// button, done. The application key lands in the synced keychain.
public struct HueSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var configs: ProviderConfigs

    @State private var phase: Phase = .searching
    @State private var found: [DiscoveredBridge] = []
    @State private var manualHost = ""
    @State private var pairingTarget: DiscoveredBridge?
    @State private var errorMessage: String?

    enum Phase {
        case searching
        case list
        case pairing
        case done
    }

    public init(configs: Binding<ProviderConfigs>) {
        _configs = configs
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                switch phase {
                case .searching:
                    ProgressView("Looking for Hue bridges…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .list:
                    bridgeList
                case .pairing:
                    pairingView
                case .done:
                    doneView
                }
            }
            .padding(20)
            .navigationTitle("Philips Hue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await search() }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
    }

    private func search() async {
        phase = .searching
        found = await HueDiscovery.discover()
        phase = .list
    }

    private var bridgeList: some View {
        VStack(spacing: 14) {
            if found.isEmpty {
                ContentUnavailableView(
                    "No bridge found automatically",
                    systemImage: "questionmark.circle",
                    description: Text("Enter your bridge's IP below — it's listed in the Hue app under Settings → My Hue System.")
                )
            } else {
                ForEach(found) { bridge in
                    Button {
                        pairingTarget = bridge
                        phase = .pairing
                    } label: {
                        HStack {
                            Image(systemName: "server.rack")
                            VStack(alignment: .leading) {
                                Text(bridge.name ?? "Hue Bridge")
                                Text(bridge.host)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if configs.hueBridges.contains(where: { $0.bridgeID == bridge.bridgeID }) {
                                Text("Paired")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .partyGlassCard()
                }
            }

            HStack {
                TextField("Bridge IP (e.g. 192.168.1.2)", text: $manualHost)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Button("Verify") {
                    Task {
                        do {
                            let bridge = try await HueDiscovery.verify(host: manualHost)
                            pairingTarget = bridge
                            phase = .pairing
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.glass)
                .disabled(manualHost.isEmpty)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Search Again") { Task { await search() } }
                .buttonStyle(.glass)

            Spacer()
        }
    }

    private var pairingView: some View {
        VStack(spacing: 22) {
            Image(systemName: "button.programmable")
                .font(.system(size: 64))
                .foregroundStyle(PartyTheme.accent)
                .symbolEffect(.pulse)

            Text("Press the link button")
                .font(.title2.weight(.semibold))
            Text("Press the round button on top of your Hue bridge (\(pairingTarget?.host ?? "")), then tap Pair within 30 seconds.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            Button("Pair") {
                Task { await pair() }
            }
            .buttonStyle(.glassProminent)
            .tint(PartyTheme.accent)
            .accessibilityIdentifier("hue-pair")

            Button("Back") {
                phase = .list
                errorMessage = nil
            }
            .buttonStyle(.glass)

            Spacer()
        }
    }

    private var doneView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Bridge paired!")
                .font(.title2.weight(.semibold))
            Text("Your Hue lights are loading. This pairing syncs to your other devices through iCloud.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .tint(PartyTheme.accent)
            Spacer()
        }
    }

    private func pair() async {
        guard let bridge = pairingTarget else { return }
        do {
            let applicationKey = try await HuePairing.createApplicationKey(host: bridge.host)
            KeychainStore.save(applicationKey, for: .hueApplicationKey, account: bridge.bridgeID)

            var updated = configs
            updated.hueBridges.removeAll { $0.bridgeID == bridge.bridgeID }
            updated.hueBridges.append(HueBridgeConfig(bridgeID: bridge.bridgeID, host: bridge.host))
            configs = updated

            errorMessage = nil
            phase = .done
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
