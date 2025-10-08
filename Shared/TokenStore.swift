import Foundation
import Security

struct TokenPair: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
}

enum TokenStore {
    private static let service = "psso"
    private static let account = "default"

    static func save(_ pair: TokenPair) {
        do {
            let data = try JSONEncoder().encode(pair)
            let q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecUseDataProtectionKeychain as String: false,
                kSecValueData as String: data
            ]
            SecItemDelete(q as CFDictionary)
            SecItemAdd(q as CFDictionary, nil)
        } catch {
            print("TokenStore save error: \(error)")
        }
    }

    static func load() -> TokenPair? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecUseDataProtectionKeychain as String: false
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            return try? JSONDecoder().decode(TokenPair.self, from: data)
        }
        return nil
    }
}

