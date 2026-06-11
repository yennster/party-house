import Foundation
import PartyCore

/// HTTPS client for one Hue bridge: CLIP v2 REST with the bridge's self-signed TLS
/// accepted, 429 rate-limit retries with exponential backoff, and writes capped at
/// 4 in flight (the bridge handles roughly 10 light writes per second).
actor HueClient {
    let host: String
    var applicationKey: String?

    private let session: URLSession
    private var inFlightWrites = 0
    private var writeWaiters: [CheckedContinuation<Void, Never>] = []

    private static let maxConcurrentWrites = 4
    private static let maxAttempts = 4

    init(host: String, applicationKey: String?) {
        self.host = host
        self.applicationKey = applicationKey
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        self.session = URLSession(
            configuration: configuration,
            delegate: HueBridgeTrustDelegate(),
            delegateQueue: nil
        )
    }

    // MARK: Requests

    func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> [T] {
        let request = try makeRequest(path: path, method: "GET")
        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)
        let envelope = try JSONDecoder().decode(HueEnvelope<T>.self, from: data)
        if let error = envelope.errors.first, envelope.data.isEmpty {
            throw ProviderError("Hue bridge error: \(error.description)")
        }
        return envelope.data
    }

    func put(path: String, body: [String: Any]) async throws {
        await acquireWriteSlot()
        defer { releaseWriteSlot() }

        var request = try makeRequest(path: path, method: "PUT")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ProviderError("Unexpected response from Hue bridge.")
                }
                if http.statusCode == 429, attempt < Self.maxAttempts {
                    let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                    let backoff = retryAfter ?? (0.4 * pow(2, Double(attempt - 1)))
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                    continue
                }
                try Self.checkStatus(response, data: data)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard attempt < Self.maxAttempts else { throw error }
                try await Task.sleep(nanoseconds: UInt64(0.3 * pow(2, Double(attempt - 1)) * 1_000_000_000))
            }
        }
    }

    /// Opens the CLIP v2 server-sent-events stream and yields raw `data:` payloads.
    func eventStreamLines() async throws -> (URLSession, AsyncLineSequence<URLSession.AsyncBytes>) {
        var request = try makeRequest(path: "/eventstream/clip/v2", method: "GET")
        request.timeoutInterval = 86_400
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        try Self.checkStatus(response, data: nil)
        return (session, bytes.lines)
    }

    // MARK: Helpers

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: "https://\(host)\(path)") else {
            throw ProviderError("Invalid bridge address: \(host)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let applicationKey {
            request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private static func checkStatus(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError("Unexpected response from Hue bridge.")
        }
        guard (200..<300).contains(http.statusCode) else {
            var detail = ""
            if let data,
               let envelope = try? JSONDecoder().decode(HueEnvelope<HueResourceRef>.self, from: data),
               let first = envelope.errors.first {
                detail = " — \(first.description)"
            }
            throw ProviderError("Hue bridge returned status \(http.statusCode)\(detail).")
        }
    }

    private func acquireWriteSlot() async {
        if inFlightWrites < Self.maxConcurrentWrites {
            inFlightWrites += 1
            return
        }
        await withCheckedContinuation { continuation in
            writeWaiters.append(continuation)
        }
        inFlightWrites += 1
    }

    private func releaseWriteSlot() {
        inFlightWrites -= 1
        if !writeWaiters.isEmpty {
            writeWaiters.removeFirst().resume()
        }
    }
}
