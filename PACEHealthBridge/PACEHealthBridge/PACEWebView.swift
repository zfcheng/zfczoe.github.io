import SwiftUI
import WebKit
import UIKit

/// The PACE website is loaded inside this app, so native HealthKit data can
/// be delivered to its JavaScript without uploading the data to a backend.
/// Note: WKWebView local storage is separate from Safari's existing PWA storage.
struct PACEWebView: UIViewRepresentable {
    @ObservedObject var bridge: BridgeController

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.userContentController.add(context.coordinator, name: "paceHealth")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = UIColor.systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        bridge.webView = webView
        let url = URL(string: "https://zfcheng.github.io/zfczoe.github.io/pace/")!
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        private let bridge: BridgeController
        private let allowedHost = "zfcheng.github.io"
        private let allowedPrefix = "/zfczoe.github.io/pace/"

        init(bridge: BridgeController) {
            self.bridge = bridge
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "paceHealth",
                  message.frameInfo.securityOrigin.host == allowedHost,
                  let body = message.body as? [String: Any],
                  body["action"] as? String == "sync" else { return }
            Task { @MainActor in bridge.sync(days: 7) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in bridge.webViewDidFinishLoading(webView) }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let isTrustedPage = url.scheme == "https"
                && url.host == allowedHost
                && url.path.hasPrefix(allowedPrefix)

            if isTrustedPage {
                decisionHandler(.allow)
                return
            }
            // Third-party video links and guides open in Safari instead of
            // receiving the HealthKit bridge in the embedded webview.
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            Task { @MainActor in
                bridge.status = "PACE 网页加载失败：请检查网络连接。\n\(error.localizedDescription)"
            }
        }
    }
}
