import SwiftUI
import WebKit

/// The Memory Web — the server's /viz page (Cytoscape force-directed graph of the
/// OKF bundle) embedded natively. The token travels in the URL fragment; the page
/// moves it to sessionStorage and strips it immediately.
struct GraphView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.043, green: 0.047, blue: 0.071, alpha: 1)  // #0b0c12
        web.scrollView.contentInsetAdjustmentBehavior = .never
        load(web)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    private func load(_ web: WKWebView) {
        var comps = URLComponents(url: Secrets.serverURL.appending(path: "/viz"),
                                  resolvingAgainstBaseURL: false)!
        comps.fragment = "token=\(Secrets.apiToken)"
        web.load(URLRequest(url: comps.url!))
    }
}
