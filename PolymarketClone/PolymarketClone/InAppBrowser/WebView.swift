import SwiftUI
import Combine
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var currentURL: String
    @Binding var pageTitle: String

    // Actions triggered from SwiftUI
    var goBackAction: Bool = false
    var goForwardAction: Bool = false
    var reloadAction: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground

        context.coordinator.webView = webView
        context.coordinator.setupObservers(webView)

        if let url = url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load new URL if different from current
        if let url = url, url.absoluteString != context.coordinator.lastLoadedURL {
            context.coordinator.lastLoadedURL = url.absoluteString
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.removeObservers(uiView)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var webView: WKWebView?
        var lastLoadedURL: String = ""
        private var observations: [NSKeyValueObservation] = []

        init(_ parent: WebView) {
            self.parent = parent
        }

        func setupObservers(_ webView: WKWebView) {
            observations = [
                webView.observe(\.canGoBack) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.canGoBack = wv.canGoBack }
                },
                webView.observe(\.canGoForward) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.canGoForward = wv.canGoForward }
                },
                webView.observe(\.isLoading) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.isLoading = wv.isLoading }
                },
                webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.progress = wv.estimatedProgress }
                },
                webView.observe(\.url) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.currentURL = wv.url?.absoluteString ?? ""
                    }
                },
                webView.observe(\.title) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.pageTitle = wv.title ?? ""
                    }
                }
            ]
        }

        func removeObservers(_ webView: WKWebView) {
            observations.removeAll()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.currentURL = webView.url?.absoluteString ?? ""
                self.parent.pageTitle = webView.title ?? ""
            }
        }
    }
}

/// Controller that holds a reference to the WKWebView for imperative actions.
class BrowserController: ObservableObject {
    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
}

/// WebView variant that exposes the WKWebView reference via BrowserController.
struct ControllableWebView: UIViewRepresentable {
    let initialURL: URL?
    @ObservedObject var controller: BrowserController
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var currentURL: String
    @Binding var pageTitle: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground

        context.coordinator.setupObservers(webView)
        controller.webView = webView

        if let url = initialURL {
            context.coordinator.lastLoadedURL = url.absoluteString
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.removeObservers()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ControllableWebView
        var lastLoadedURL: String = ""
        private var observations: [NSKeyValueObservation] = []

        init(_ parent: ControllableWebView) {
            self.parent = parent
        }

        func setupObservers(_ webView: WKWebView) {
            observations = [
                webView.observe(\.canGoBack) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.canGoBack = wv.canGoBack }
                },
                webView.observe(\.canGoForward) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.canGoForward = wv.canGoForward }
                },
                webView.observe(\.isLoading) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.isLoading = wv.isLoading }
                },
                webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.parent.progress = wv.estimatedProgress }
                },
                webView.observe(\.url) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.currentURL = wv.url?.absoluteString ?? ""
                    }
                },
                webView.observe(\.title) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.pageTitle = wv.title ?? ""
                    }
                }
            ]
        }

        func removeObservers() {
            observations.removeAll()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.currentURL = webView.url?.absoluteString ?? ""
                self.parent.pageTitle = webView.title ?? ""
            }
        }
    }
}
