import CryptoKit
import Foundation
import Security

struct SocialProviderAvailability: Decodable, Sendable {
    let external: [String: Bool]
    var apple: Bool { external["apple"] == true }
    var google: Bool { external["google"] == true }
}

enum SocialSignIn {
    static let callbackURL = URL(string: "com.kevin.opportunity313://auth/callback")!

    static func acceptsCallback(_ url: URL) -> Bool {
        url.scheme == callbackURL.scheme && url.host == callbackURL.host && url.path == callbackURL.path
    }

    static func nonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw Failure(message: "Unable to start secure sign-in. Please try again.")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
