import SwiftUI
import WebKit
import os

/// 内嵌 Roblox 官方登录页，登录完成后自动抓 .ROBLOSECURITY。
/// 用 non-persistent 的 WKWebsiteDataStore：每次添加都是干净的，不残留上一个账号。
private let log = Logger(subsystem: "com.epmulti.exolocal", category: "webview")

final class LoginSession: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var status: String = L.t("正在打开 Roblox 登录页…", "Opening the Roblox login page…")
    @Published var busy = false

    let dataStore = WKWebsiteDataStore.nonPersistent()
    private var timer: Timer?
    private var grabbed = false
    private weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        start()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkCookies()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        grabbed = false
        busy = false
        start()
    }

    func reload() {
        reset()
        webView?.load(URLRequest(url: URL(string: "https://www.roblox.com/login")!))
    }

    private func checkCookies() {
        guard !grabbed else { return }
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            guard let c = cookies.first(where: {
                $0.name == ".ROBLOSECURITY" && $0.domain.contains("roblox")
            }), c.value.hasPrefix("_|WARNING:-DO-NOT-SHARE-THIS.") else { return }

            DispatchQueue.main.async {
                guard !self.grabbed else { return }
                self.grabbed = true
                self.stop()
                self.busy = true
                self.status = L.t("已抓到登录态，正在添加…", "Captured the session — adding…")
                log.info("captured session for \(c.domain, privacy: .public) len=\(c.value.count)")
                self.pendingCookie = c.value
            }
        }
    }

    /// 抓到的会话交给外层（只走内存，不落盘）
    var pendingCookie: String? {
        didSet {
            if let c = pendingCookie { onCookie?(c) }
        }
    }
    var onCookie: ((String) -> Void)?

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.info("finished \(webView.url?.absoluteString ?? "?", privacy: .public)")
        if !grabbed, !busy {
            status = L.t("请在下面登录 Roblox（支持两步验证）", "Sign in to Roblox below (2-step verification supported)")
        }
        checkCookies()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log.error("failed \(error.localizedDescription, privacy: .public)")
        if !grabbed { status = L.t("网页加载失败：", "Page failed to load: ") + error.localizedDescription }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if !grabbed { status = L.t("网络不可用：", "Network error: ") + error.localizedDescription }
    }
}

struct LoginWebView: NSViewRepresentable {
    let session: LoginSession
    let onCookie: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = session.dataStore
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = session
        // 用普通 Safari UA，避免个别站点对嵌入式 WebView 区别对待
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        session.onCookie = onCookie
        session.attach(wv)
        wv.load(URLRequest(url: URL(string: "https://www.roblox.com/login")!))
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

/// 登录面板：顶部状态条 + 官方登录页
struct LoginPanel: View {
    @EnvironmentObject var store: Store
    var onAdded: (String) -> Void
    @StateObject private var session = LoginSession()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if session.busy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "lock.shield").font(.caption).foregroundStyle(.secondary)
                }
                Text(session.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L.t("重新加载", "Reload")) { session.reload() }
                    .controlSize(.small)
                    .disabled(session.busy)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)

            LoginWebView(session: session) { cookie in
                store.addAuto(cookie) { name in
                    if let name {
                        session.status = L.t("已添加 \(name)", "Added \(name)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onAdded(name) }
                    } else {
                        session.status = L.t("添加失败：会话无效或网络问题，请重试",
                                             "Failed: invalid session or network issue — try again")
                        session.busy = false
                        session.reset()
                    }
                }
            }
        }
    }
}
