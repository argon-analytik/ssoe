//
//  AuthenticationViewController+Shared.swift
//  Scissors
//
//  Created by Timothy Perfitt on 4/4/24.
//

import Foundation
import AuthenticationServices
import WebKit

protocol WebViewSSOProtocol {
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!)
}

protocol ExtensionAuthorizationRequestProtocol {
    func process(_ request:ASAuthorizationProviderExtensionAuthorizationRequest)

}
extension AuthenticationViewController:WebViewSSOProtocol, WKNavigationDelegate {

    private static let fallbackRedirectURI = "ch.argio.psso://oauth/callback"
    private var oidcRedirectURI: String {
        (objc_getAssociatedObject(self, &AssociatedKeys.redirectURI) as? String) ?? Self.fallbackRedirectURI
    }
    private var pkce: PKCE? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.pkce) as? PKCE }
        set { objc_setAssociatedObject(self, &AssociatedKeys.pkce, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private struct AssociatedKeys { static var pkce = "pkce"; static var redirectURI = "redirectURI" }

    func setupWebViewAndDelegate() {
        if let url = url {
            webView.navigationDelegate=self
            var request = URLRequest(url: url)
            let cookies = cookiesFromKeychain()

            if let cookies = cookies {
                request.setValue(cookieHeaderString(from: cookies), forHTTPHeaderField: "Cookie")
            }
            request.httpShouldHandleCookies=true
            webView.load(request)
        }
    }

    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let originalURL = url, let webViewURL = webView.url else {
            return
        }

        // If we have an OIDC redirect with code, exchange for tokens
        if let components = URLComponents(url: webViewURL, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           components.string?.hasPrefix(oidcRedirectURI) == true,
           let request = authorizationRequest {
            let config = OIDCConfig.from(request: request)
            let pkce = self.pkce
            self.pkce = nil
            let codeVerifier = pkce?.verifier ?? ""
            if let config = config, !codeVerifier.isEmpty {
                OIDCFlow.exchangeCodeForTokens(config: config, code: code, codeVerifier: codeVerifier, redirectURI: oidcRedirectURI) { result in
                    switch result {
                    case .success(let pair):
                        TokenStore.save(pair)
                        let headers = ["Authorization": "Bearer \(pair.accessToken)"]
                        if let response = HTTPURLResponse(url: originalURL, statusCode: 200, httpVersion: nil, headerFields: headers) {
                            request.complete(httpResponse: response, httpBody: nil)
                        } else {
                            request.complete()
                        }
                    case .failure(let err):
                        request.complete(error: err)
                    }
                }
                return
            }
        }

        if let authorizationRequestHost = authorizationRequest?.url.host, webViewURL.host() != authorizationRequestHost {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies({ cookies in
                let headers: [String:String] = [
                    "Location": webViewURL.absoluteString,
                    "Set-Cookie": cookieHeaderString(from: cookies)
                ]
                let _ = storeCookiesInKeychain(cookies)
                if let response = HTTPURLResponse.init(url: originalURL, statusCode: 302, httpVersion: nil, headerFields: headers) {
                    self.authorizationRequest?.complete(httpResponse: response, httpBody: nil)
                }
            })
        }

    }
}
extension AuthenticationViewController:ExtensionAuthorizationRequestProtocol {

    func process(_ request:ASAuthorizationProviderExtensionAuthorizationRequest){
        // Attempt token refresh if we have an expired access token
        if let config = OIDCConfig.from(request: request), let pair = TokenStore.load() {
            if let exp = pair.expiresAt, exp < Date(), let rt = pair.refreshToken {
                OIDCFlow.refreshAccessToken(config: config, refreshToken: rt) { result in
                    switch result {
                    case .success(let newPair):
                        TokenStore.save(newPair)
                        let headers = ["Authorization": "Bearer \(newPair.accessToken)"]
                        if let resp = HTTPURLResponse(url: request.url ?? URL(string: "https://localhost/")!, statusCode: 200, httpVersion: nil, headerFields: headers) {
                            request.complete(httpResponse: resp, httpBody: nil)
                        } else {
                            request.complete()
                        }
                    case .failure:
                        break // proceed to interactive auth
                    }
                }
                return
            } else if let exp = pair.expiresAt, exp > Date() {
                // token valid; return immediately
                let headers = ["Authorization": "Bearer \(pair.accessToken)"]
                if let resp = HTTPURLResponse(url: request.url ?? URL(string: "https://localhost/")!, statusCode: 200, httpVersion: nil, headerFields: headers) {
                    request.complete(httpResponse: resp, httpBody: nil)
                    return
                }
            }
        }

        // If request URL matches issuer domain, initiate OIDC authorize with PKCE
        let config = OIDCConfig.from(request: request)
        if let issuerHost = config?.issuer.host,
           let reqURL = request.url,
           reqURL.host == issuerHost,
           let authorize = config?.authorize {
            let pkce = PKCE.generate()
            self.pkce = pkce
            if let ru = config?.redirectURI, !ru.isEmpty { objc_setAssociatedObject(self, &AssociatedKeys.redirectURI, ru, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            var comps = URLComponents(url: authorize, resolvingAgainstBaseURL: false)!
            let items: [URLQueryItem] = [
                .init(name: "response_type", value: "code"),
                .init(name: "client_id", value: config?.clientID),
                .init(name: "redirect_uri", value: oidcRedirectURI),
                .init(name: "scope", value: config?.scopes),
                .init(name: "code_challenge_method", value: "S256"),
                .init(name: "code_challenge", value: pkce.challenge)
            ]
            comps.queryItems = (comps.queryItems ?? []) + items
            url = comps.url
        } else {
            url = request.url
        }
        request.presentAuthorizationViewController(completion: { (success, error) in
            if error != nil {
                request.complete(error: error!)
            }
        })
    }
}
extension AuthenticationViewController: ASAuthorizationProviderExtensionAuthorizationRequestHandler {

    public func beginAuthorization(with request: ASAuthorizationProviderExtensionAuthorizationRequest) {
        self.authorizationRequest = request

        process(request)
    }
}
