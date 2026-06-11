import Foundation
import PartyCore

/// The link-button pairing flow: POST /api until the user presses the bridge button.
public enum HuePairing {
    public enum PairingError: LocalizedError {
        case linkButtonNotPressed
        case bridgeRejected(String)

        public var errorDescription: String? {
            switch self {
            case .linkButtonNotPressed:
                return "Press the round link button on your Hue bridge, then try again."
            case .bridgeRejected(let message):
                return message
            }
        }
    }

    struct CreateKeyResponse: Decodable {
        struct Success: Decodable {
            let username: String
        }

        struct APIError: Decodable {
            let type: Int
            let description: String
        }

        let success: Success?
        let error: APIError?
    }

    /// Asks the bridge for an application key. Throws `.linkButtonNotPressed`
    /// (Hue error type 101) until the physical button has been pressed.
    public static func createApplicationKey(host: String) async throws -> String {
        guard let url = URL(string: "https://\(host)/api") else {
            throw ProviderError("Invalid bridge address.")
        }

        #if os(macOS)
        let platform = "mac"
        #else
        let platform = "ios"
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "devicetype": "party_house#\(platform)",
            "generateclientkey": true,
        ])

        let session = URLSession(configuration: .ephemeral, delegate: HueBridgeTrustDelegate(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (data, _) = try await session.data(for: request)
        let responses = try JSONDecoder().decode([CreateKeyResponse].self, from: data)

        if let success = responses.compactMap(\.success).first {
            return success.username
        }
        if let error = responses.compactMap(\.error).first {
            if error.type == 101 {
                throw PairingError.linkButtonNotPressed
            }
            throw PairingError.bridgeRejected(error.description)
        }
        throw ProviderError("Unexpected pairing response from the bridge.")
    }
}
