import AppKit
import WebKit

/// Çalan şarkının güncel durumu. SwiftUI mini oynatıcı bunu izler.
final class PlayerState: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var album = ""
    @Published var artworkURL = ""
    @Published var artwork: NSImage?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0

    var hasTrack: Bool { !title.isEmpty }
}

private struct Snapshot: Decodable {
    let title: String
    let artist: String
    let album: String
    let artwork: String
    let playing: Bool
    let position: Double
    let duration: Double
}

/// WKWebView'i barındırır, sayfadaki köprü script'i ile konuşur.
final class PlayerController: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    static let home = URL(string: "https://music.youtube.com")!

    // Google, gömülü tarayıcılarda girişi engelleyebiliyor; Safari gibi görünüyoruz.
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    private static let internalDomains = [
        "youtube.com", "youtu.be", "youtube-nocookie.com", "google.com", "gstatic.com",
        "googleusercontent.com", "ggpht.com", "googleapis.com", "googlevideo.com",
    ]

    let state = PlayerState()
    let webView: WKWebView

    var onStateChange: (() -> Void)?
    var onTrackChange: (() -> Void)?

    private var timer: Timer?
    private var artworkTask: URLSessionDataTask?

    override init() {
        let contentController = WKUserContentController()
        if let url = Bundle.main.url(forResource: "Bridge", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            contentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Girişin kalıcı olması için
        config.userContentController = contentController
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        contentController.add(self, name: "ytm")
        webView.customUserAgent = Self.userAgent
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = .black
        webView.pageZoom = UserDefaults.standard.double(forKey: "pageZoom")
        webView.load(URLRequest(url: Self.home))

        // Pencere gizliyken sayfa zamanlayıcıları yavaşlayabilir; durumu buradan da okuyoruz.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Komutlar

    func togglePlayPause() {
        state.isPlaying.toggle()
        run("toggle")
    }
    func play() { run("play") }
    func pause() { run("pause") }
    func next() { run("next") }
    func previous() { run("previous") }
    func seek(to seconds: Double) {
        state.position = seconds
        run("seek", seconds)
    }

    func goHome() { webView.load(URLRequest(url: Self.home)) }

    func setZoom(_ zoom: Double) {
        let clamped = min(max(zoom, 0.5), 2.0)
        webView.pageZoom = clamped
        UserDefaults.standard.set(clamped, forKey: "pageZoom")
    }

    private func run(_ command: String, _ argument: Double = 0) {
        webView.evaluateJavaScript("window.__ytmCmd && window.__ytmCmd('\(command)', \(argument))") { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.poll() }
        }
    }

    // MARK: - Durum

    private func poll() {
        webView.evaluateJavaScript("window.__ytmState && JSON.stringify(window.__ytmState())") { [weak self] result, _ in
            if let json = result as? String { self?.apply(json) }
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if let json = message.body as? String { apply(json) }
    }

    private func apply(_ json: String) {
        guard let data = json.data(using: .utf8),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }

        let trackChanged = snap.title != state.title || snap.artist != state.artist
        if trackChanged {
            state.title = snap.title
            state.artist = snap.artist
        }
        if snap.album != state.album { state.album = snap.album }
        if snap.playing != state.isPlaying { state.isPlaying = snap.playing }
        state.position = snap.position
        if snap.duration != state.duration { state.duration = snap.duration }
        if snap.artwork != state.artworkURL { loadArtwork(snap.artwork) }

        if trackChanged && !snap.title.isEmpty { onTrackChange?() }
        onStateChange?()
    }

    private func loadArtwork(_ urlString: String) {
        state.artworkURL = urlString
        state.artwork = nil
        artworkTask?.cancel()
        guard let url = URL(string: urlString) else { return }
        artworkTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                guard let self, self.state.artworkURL == urlString else { return }
                self.state.artwork = image
                self.onStateChange?()
            }
        }
        artworkTask?.resume()
    }

    // MARK: - Gezinme

    private static func isInternal(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        if host.hasPrefix("accounts.google.") { return true }
        return internalDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// YouTube/Google dışındaki bağlantılar varsayılan tarayıcıda açılır.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url,
           url.scheme?.hasPrefix("http") == true, !Self.isInternal(url) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    /// Yeni pencere isteyen bağlantılar: içeridekiler aynı pencerede, diğerleri tarayıcıda.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if Self.isInternal(url) { webView.load(action.request) } else { NSWorkspace.shared.open(url) }
        }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}
