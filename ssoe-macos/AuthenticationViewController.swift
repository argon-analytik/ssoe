//
//  AuthenticationViewController.swift
//  ssoe-ios
//
//  Created by Timothy Perfitt on 4/17/24.
//

import WebKit
import AuthenticationServices

#if os(macOS)
import AppKit
class AuthenticationViewController: NSViewController {
    var webView: WKWebView!
    var url: URL?
    var authorizationRequest: ASAuthorizationProviderExtensionAuthorizationRequest?

    @IBAction func cancelButtonPressed(_ sender: Any?) {
        self.authorizationRequest?.doNotHandle()
    }

    override func loadView() {
        self.webView = WKWebView(frame: .zero)
        self.view = self.webView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupWebViewAndDelegate()
    }
}
#else
import UIKit
class AuthenticationViewController: UIViewController {
    @IBOutlet weak var webView: WKWebView!
    var url: URL?
    var authorizationRequest: ASAuthorizationProviderExtensionAuthorizationRequest?

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.authorizationRequest?.doNotHandle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupWebViewAndDelegate()
    }

    override var nibName: String? {
        return "AuthenticationViewController"
    }
}
#endif
