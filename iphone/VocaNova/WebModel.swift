import SwiftUI
import WebKit

/// Owns the web view that runs Voca Nova and handles the things a browser
/// normally would: microphone permission, pop-up dialogs, outside links.
final class WebModel: NSObject, ObservableObject {
    /// The live site. Loading it (instead of a copy inside the app) keeps the
    /// app up to date with every change and lets the AI coach accept requests.
    static let home = URL(string: "https://sionamehta.github.io/VocaNova/")!
    /// Sites the app opens itself. Anything else opens in Safari.
    private static let ownHosts: Set<String> = ["sionamehta.github.io", "vocanova-coach.sionamehta1.workers.dev"]

    @Published var loading = true
    @Published var loadedOnce = false
    @Published var failed = false

    let webView: WKWebView
    private let speech: SpeechBridge

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Mobile/15E148 Safari/604.1 VocaNovaApp"

        // "Hey Voca" uses the browser's speech recognition. Give the page a
        // version backed by iOS's own recognizer so it works inside the app.
        let speech = SpeechBridge()
        let scripts = config.userContentController
        scripts.add(speech, name: SpeechBridge.handlerName)
        scripts.addUserScript(WKUserScript(source: SpeechBridge.script,
                                           injectionTime: .atDocumentStart,
                                           forMainFrameOnly: true))

        self.speech = speech
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        speech.webView = webView
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBackground")
        webView.scrollView.backgroundColor = UIColor(named: "LaunchBackground")
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(pulledToRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        webView.load(URLRequest(url: WebModel.home))
    }

    func reload() {
        failed = false
        loading = true
        if webView.url == nil {
            webView.load(URLRequest(url: Self.home))
        } else {
            webView.reload()
        }
    }

    @objc private func pulledToRefresh(_ sender: UIRefreshControl) {
        reload()
        sender.endRefreshing()
    }

    private var topViewController: UIViewController? {
        var vc = webView.window?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

extension WebModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading = true
        speech.stopAll()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false
        loadedOnce = true
        failed = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    private func handleFailure(_ error: Error) {
        loading = false
        // A cancelled load (for example a quick second refresh) isn't a real failure.
        if (error as NSError).code == NSURLErrorCancelled { return }
        if !loadedOnce { failed = true }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        let scheme = url.scheme?.lowercased() ?? ""
        let isWeb = scheme == "http" || scheme == "https"
        let isOwn = Self.ownHosts.contains(url.host?.lowercased() ?? "")
        if (isWeb && !isOwn && navigationAction.targetFrame?.isMainFrame != false)
            || ["mailto", "tel", "sms"].contains(scheme) {
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }
}

extension WebModel: WKUIDelegate {
    // The app already asked for the microphone, so don't ask again for every page.
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    // Links that would open a new tab open in Safari instead.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if Self.ownHosts.contains(url.host?.lowercased() ?? "") {
                webView.load(navigationAction.request)
            } else {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        guard let top = topViewController else { return completionHandler() }
        top.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        guard let top = topViewController else { return completionHandler(false) }
        top.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        guard let top = topViewController else { return completionHandler(nil) }
        top.present(alert, animated: true)
    }
}
