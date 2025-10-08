import Foundation
import AuthenticationServices

struct OIDCConfig {
    let issuer: URL
    let authorize: URL
    let token: URL
    let scopes: String
    let clientID: String
    let clientSecret: String?
    let redirectURI: String?

    static func from(request: ASAuthorizationProviderExtensionAuthorizationRequest) -> OIDCConfig? {
        // Best-effort: read from Extensible SSO AdditionalSettings
        // The API does not expose a typed struct; use KVC to access a backing dictionary if present.
        if let providerConfig = request.value(forKey: "providerConfiguration") as? [String: Any] {
            let additional = providerConfig["AdditionalSettings"] as? [String: Any]
            let issuer = (additional?["issuer"] as? String) ?? (providerConfig["ASAuthorizationProviderExtensionIssuer"] as? String)
            let authorize = (additional?["authorize"] as? String)
            let token = (additional?["token"] as? String)
            let scopes = (additional?["scopes"] as? String) ?? "openid profile email offline_access"
            let clientID = (additional?["client_id"] as? String)
            let clientSecret = (additional?["client_secret"] as? String)
            let redirectURI = (additional?["redirect_uri"] as? String)

            if let issuer, let authorize, let token, let clientID,
               let issuerURL = URL(string: issuer),
               let authorizeURL = URL(string: authorize),
               let tokenURL = URL(string: token) {
                return OIDCConfig(issuer: issuerURL,
                                  authorize: authorizeURL,
                                  token: tokenURL,
                                  scopes: scopes,
                                  clientID: clientID,
                                  clientSecret: clientSecret,
                                  redirectURI: redirectURI)
            }
        }

        // Fallback to defaults matching repo constants
        let issuer = URL(string: "https://auth.argio.ch")!
        return OIDCConfig(issuer: issuer,
                          authorize: issuer.appendingPathComponent("application/o/authorize/"),
                          token: issuer.appendingPathComponent("application/o/token/"),
                          scopes: "openid profile email offline_access",
                          clientID: "ch.argio.sso",
                          clientSecret: nil,
                          redirectURI: nil)
    }
}
