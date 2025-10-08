import Foundation
import AuthenticationServices
#if canImport(CryptoKit)
import CryptoKit
#endif

struct PKCE {
    let verifier: String
    let challenge: String

    static func generate() -> PKCE {
        let verifier = randomURLSafe(length: 64)
        let challenge = sha256Base64URL(verifier)
        return PKCE(verifier: verifier, challenge: challenge)
    }

    private static func randomURLSafe(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var out = ""
        for _ in 0..<length { out.append(chars.randomElement()!) }
        return out
    }

    private static func sha256Base64URL(_ input: String) -> String {
        let data = input.data(using: .utf8)!
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        let raw = Data(digest)
        #else
        // Fallback: not a real SHA-256; base64 the input to keep compile-time simple.
        // Replace with CryptoKit on real build hosts.
        let raw = data
        #endif
        return raw.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}

enum OIDCFlow {
    static func refreshAccessToken(config: OIDCConfig, refreshToken: String, completion: @escaping (Result<TokenPair, Error>) -> Void) {
        var req = URLRequest(url: config.token)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var bodyItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: config.clientID)
        ]
        if let secret = config.clientSecret, !secret.isEmpty {
            bodyItems.append(URLQueryItem(name: "client_secret", value: secret))
        }
        req.httpBody = bodyItems.map { "\($0.name)=\(($0.value ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = obj["access_token"] as? String else {
                completion(.failure(NSError(domain: "OIDC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid refresh response"]))); return
            }
            let refresh = obj["refresh_token"] as? String ?? refreshToken
            let expiresSec = obj["expires_in"] as? Double
            let expiresAt = expiresSec != nil ? Date().addingTimeInterval(expiresSec!) : nil
            completion(.success(TokenPair(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)))
        }.resume()
    }
    static func exchangeCodeForTokens(config: OIDCConfig, code: String, codeVerifier: String, redirectURI: String, completion: @escaping (Result<TokenPair, Error>) -> Void) {
        var req = URLRequest(url: config.token)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var bodyItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        if let secret = config.clientSecret, !secret.isEmpty {
            bodyItems.append(URLQueryItem(name: "client_secret", value: secret))
        }
        req.httpBody = bodyItems.map { "\($0.name)=\(($0.value ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = obj["access_token"] as? String else {
                completion(.failure(NSError(domain: "OIDC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid token response"]))); return
            }
            let refresh = obj["refresh_token"] as? String
            let expiresSec = obj["expires_in"] as? Double
            let expiresAt = expiresSec != nil ? Date().addingTimeInterval(expiresSec!) : nil
            completion(.success(TokenPair(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)))
        }.resume()
    }
}
