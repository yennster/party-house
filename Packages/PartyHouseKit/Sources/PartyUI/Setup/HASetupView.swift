import SwiftUI
import PartyCore

/// Home Assistant onboarding: internal + external URLs and a long-lived access
/// token, with a live connection test. Mirrors the official companion app's
/// internal/external model.
public struct HASetupView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var configs: ProviderConfigs

    @State private var internalURL: String
    @State private var externalURL: String
    @State private var token: String
    @State private var testResult: TestResult?
    @State private var testing = false

    enum TestResult {
        case success(String)
        case failure(String)
    }

    public init(configs: Binding<ProviderConfigs>) {
        _configs = configs
        _internalURL = State(initialValue: configs.wrappedValue.homeAssistant?.internalURL ?? "http://homeassistant.local:8123")
        _externalURL = State(initialValue: configs.wrappedValue.homeAssistant?.externalURL ?? "")
        _token = State(initialValue: KeychainStore.read(.homeAssistantToken) ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://homeassistant.local:8123", text: $internalURL)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("ha-internal-url")
                } header: {
                    Text("Internal URL (home Wi-Fi)")
                } footer: {
                    Text("The address that works when you're at home. For a Home Assistant Green, the default is http://homeassistant.local:8123.")
                }

                Section {
                    TextField("ha.example.com or yourhome.ui.nabu.casa", text: $externalURL)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("ha-external-url")
                } header: {
                    Text("External URL (everywhere else) — optional")
                } footer: {
                    Text("Lets Party House control your lights from anywhere — your own domain behind a reverse proxy, Nabu Casa, Cloudflare Tunnel, or Tailscale all work. https:// is assumed if you leave the scheme off. See “Control from anywhere” in Settings for walkthroughs.")
                }

                Section {
                    SecureField("Paste token", text: $token)
                        .accessibilityIdentifier("ha-token")
                } header: {
                    Text("Long-lived access token")
                } footer: {
                    Text("Create one in Home Assistant: click your user name (bottom-left) → Security → Long-lived access tokens → Create token. Stored in iCloud Keychain, end-to-end encrypted.")
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        if testing {
                            ProgressView()
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(token.isEmpty || internalURL.isEmpty || testing)
                    .accessibilityIdentifier("ha-test")

                    if let testResult {
                        switch testResult {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Home Assistant")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(token.isEmpty || internalURL.isEmpty)
                        .accessibilityIdentifier("ha-save")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }

    private func test() async {
        testing = true
        defer { testing = false }

        let candidates = [internalURL, externalURL]
            .map(HomeAssistantConfig.normalized)
            .filter { !$0.isEmpty }
            .compactMap(URL.init(string:))

        for url in candidates {
            var request = URLRequest(url: url.appendingPathComponent("api/"))
            request.timeoutInterval = 5
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse else { continue }
            if http.statusCode == 200 {
                testResult = .success("Connected via \(url.host() ?? url.absoluteString)")
                return
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                testResult = .failure("Server found, but the token was rejected. Double-check the token.")
                return
            }
        }
        testResult = .failure("Couldn't reach Home Assistant. Verify the URL and that you're on the same network.")
    }

    private func save() {
        KeychainStore.save(token, for: .homeAssistantToken)
        let external = HomeAssistantConfig.normalized(externalURL)
        var updated = configs
        updated.homeAssistant = HomeAssistantConfig(
            internalURL: HomeAssistantConfig.normalized(internalURL),
            externalURL: external.isEmpty ? nil : external
        )
        configs = updated
        dismiss()
    }
}
