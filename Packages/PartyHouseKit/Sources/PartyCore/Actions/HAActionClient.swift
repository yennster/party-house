import Foundation

/// Minimal Home Assistant REST client for widget intents — one-shot service calls,
/// no WebSocket. Tries each configured URL (internal first, then external).
public struct HAActionClient: Sendable {
    let urls: [URL]
    let token: String

    public init(urls: [URL], token: String) {
        self.urls = urls
        self.token = token
    }

    public func setPower(_ on: Bool, entityIDs: [String]) async throws {
        try await callService(
            on ? "turn_on" : "turn_off",
            payload: ["entity_id": entityIDs]
        )
    }

    public func setColor(_ color: PHColor, entityIDs: [String]) async throws {
        let rgb = color.rgb255
        try await callService(
            "turn_on",
            payload: [
                "entity_id": entityIDs,
                "rgb_color": [rgb.red, rgb.green, rgb.blue],
            ]
        )
    }

    public func setBrightness(_ value: Double, entityIDs: [String]) async throws {
        try await callService(
            "turn_on",
            payload: [
                "entity_id": entityIDs,
                "brightness": Int((min(max(value, 0), 1) * 255).rounded()),
            ]
        )
    }

    private func callService(_ service: String, payload: [String: Any]) async throws {
        guard !urls.isEmpty else { throw ProviderError("Home Assistant URL missing.") }

        var lastError: Error = ProviderError("Home Assistant is unreachable.")
        for url in urls {
            do {
                try await post(url.appendingPathComponent("api/services/light/\(service)"), payload: payload)
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func post(_ url: URL, payload: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ProviderError("Home Assistant returned status \(code).")
        }
    }
}
