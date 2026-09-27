import CryptoKit
import Foundation
import Security

protocol GooglePKCEProviding {
    func makeVerifier() throws -> String
    func challenge(for verifier: String) -> String
}

struct GooglePKCE: GooglePKCEProviding {
    func makeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw GoogleOAuthError.unavailable
        }
        return Self.base64URL(Data(bytes))
    }

    func challenge(for verifier: String) -> String {
        Self.challenge(for: verifier)
    }

    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
