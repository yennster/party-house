import Foundation

/// Minimal one-shot Hue CLIP v2 client for widget intents. The full-featured client
/// (discovery, SSE, rate limiting) lives in the PartyHue module; this one only needs
/// to fire a handful of PUTs from a short-lived extension process.
public struct HueActionClient: Sendable {
    let host: String
    let applicationKey: String

    public init(host: String, applicationKey: String) {
        self.host = host
        self.applicationKey = applicationKey
    }

    public func setPower(_ on: Bool, lightIDs: [String]) async throws {
        for id in lightIDs {
            try await put(path: "/clip/v2/resource/light/\(id)", body: ["on": ["on": on]])
        }
    }

    public func setColor(_ color: PHColor, lightID: String) async throws {
        let (xy, _) = ColorMath.xy(from: color)
        let body: [String: Any] = [
            "on": ["on": true],
            "color": ["xy": ["x": xy.x, "y": xy.y]],
        ]
        try await put(path: "/clip/v2/resource/light/\(lightID)", body: body)
    }

    public func setGradient(_ points: [PHColor], lightID: String) async throws {
        let gradientPoints = points.prefix(5).map { point -> [String: Any] in
            let (xy, _) = ColorMath.xy(from: point)
            return ["color": ["xy": ["x": xy.x, "y": xy.y]]]
        }
        let body: [String: Any] = [
            "on": ["on": true],
            "gradient": ["points": gradientPoints],
        ]
        try await put(path: "/clip/v2/resource/light/\(lightID)", body: body)
    }

    private func put(path: String, body: [String: Any]) async throws {
        guard let url = URL(string: "https://\(host)\(path)") else {
            throw ProviderError("Invalid bridge address.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 8
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let session = URLSession(
            configuration: .ephemeral,
            delegate: HueBridgeTrustDelegate(),
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ProviderError("Hue bridge returned status \(code).")
        }
    }
}

/// Hue bridges serve a certificate signed by Signify's private root CA, so default
/// TLS validation fails. We accept the bridge's server trust — traffic stays on the
/// local network and is authenticated by the application key.
public final class HueBridgeTrustDelegate: NSObject, URLSessionDelegate, Sendable {
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
