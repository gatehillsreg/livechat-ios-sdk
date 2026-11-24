#if canImport(UIKit) && canImport(WebKit)
import SafariServices
import UIKit
import WebKit

/// The one chat of the app: a WKWebView with the livechat.ae widget in "sdk" mode.
///
/// The web view lives as long as the app, also while the chat window is closed (parked,
/// invisible, behind the app's views): so the conversation stays connected, messages and
/// the unread count arrive, and opening the chat is instant. When the app goes to the
/// background the connection closes (for agents the visitor has left) and reopens on return.
@MainActor
final class ChatSession: NSObject {
    static let shared = ChatSession()

    private(set) var configuration: LiveChatAEConfiguration?
    private(set) var unread = 0
    private(set) var isPresented = false

    // what the app said about the visitor: replayed to every page load
    private var visitor: [String: String] = [:]
    private var fields: [String: String]?
    private var identity: String?
    private var department: String?
    private var departmentSet = false
    private var pushToken: String?

    private var webView: WKWebView?
    private var pageReady = false
    private var loadFailed = false
    private weak var chatController: ChatViewController?
    private let parking: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.accessibilityElementsHidden = true
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return v
    }()

    private override init() {
        super.init()
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(windowDidBecomeKey), name: UIWindow.didBecomeKeyNotification, object: nil)
    }

    // MARK: - Setup

    func configure(_ c: LiveChatAEConfiguration) {
        guard c != configuration else { return }
        configuration = c
        if !departmentSet { department = c.department }
        guard c.chatURL != nil else { fail(.invalidKey); return }
        load()
    }

    private func makeWebView() -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.websiteDataStore = .default()   // the conversation survives app restarts
        conf.allowsInlineMediaPlayback = true
        conf.applicationNameForUserAgent = "Mobile/15E148 livechat.ae-ios-sdk/\(LiveChatAE.version)"
        conf.userContentController.add(WeakMessageHandler(self), name: "livechatae")
        let w = WKWebView(frame: UIScreen.main.bounds, configuration: conf)
        w.navigationDelegate = self
        w.uiDelegate = self
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.isScrollEnabled = false
        w.scrollView.bounces = false
        w.scrollView.contentInsetAdjustmentBehavior = .never
        w.allowsLinkPreview = false
        #if DEBUG
        if #available(iOS 16.4, *) { w.isInspectable = true }
        #endif
        return w
    }

    private func load() {
        guard let url = configuration?.chatURL else { return }
        let w = webView ?? makeWebView()
        webView = w
        pageReady = false
        loadFailed = false
        // what the app already knows goes in before the widget starts (window.LiveChatAE as a queue)
        w.configuration.userContentController.removeAllUserScripts()
        w.configuration.userContentController.addUserScript(
            WKUserScript(source: Script.queue(queuedCalls()), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        w.load(URLRequest(url: url))
        if w.superview == nil { park() }
    }

    private func queuedCalls() -> [(String, Any)] {
        var calls: [(String, Any)] = []
        if !visitor.isEmpty { calls.append(("setVisitor", visitor)) }
        if let fields { calls.append(("setVariables", fields)) }
        if let identity { calls.append(("identify", identity)) }
        if departmentSet { calls.append(("setDepartment", department ?? "")) }
        if let pushToken { calls.append(("setPushToken", ["platform": "ios", "device": pushToken])) }
        return calls
    }

    private func run(_ name: String, _ argument: Any? = nil) {
        guard let w = webView, pageReady else { return }   // before "ready", the user script has it all
        w.evaluateJavaScript(Script.call(name, argument), completionHandler: nil)
    }

    // MARK: - Visitor

    func setVisitor(name: String?, email: String?) {
        visitor = [:]
        if let name, !name.isEmpty { visitor["name"] = name }
        if let email, !email.isEmpty { visitor["email"] = email }
        refreshUserScript()
        run("setVisitor", visitor)
    }

    func setCustomFields(_ f: [String: String]) {
        fields = f
        refreshUserScript()
        run("setVariables", f)
    }

    func identify(_ token: String?) {
        identity = token?.isEmpty == false ? token : nil
        refreshUserScript()
        run("identify", identity ?? "")
    }

    func setDepartment(_ name: String?) {
        department = name?.isEmpty == false ? name : nil
        departmentSet = true
        refreshUserScript()
        run("setDepartment", department ?? "")
    }

    func setPushToken(_ hex: String?) {
        pushToken = hex
        refreshUserScript()
        run("setPushToken", ["platform": "ios", "device": hex ?? ""])
    }

    /// The user script runs again at every load (reconfigure, reset, crash of the web process).
    private func refreshUserScript() {
        guard let w = webView else { return }
        w.configuration.userContentController.removeAllUserScripts()
        w.configuration.userContentController.addUserScript(
            WKUserScript(source: Script.queue(queuedCalls()), injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    func reset() {
        visitor = [:]; fields = nil; identity = nil
        setUnread(0)
        guard let server = configuration?.server.host else { return }
        let store = WKWebsiteDataStore.default()
        store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { [weak self] records in
            let mine = records.filter { server.hasSuffix($0.displayName) || $0.displayName.hasSuffix(server) }
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: mine) {
                Task { @MainActor in self?.load() }
            }
        }
    }

    // MARK: - Window

    func present(from presenter: UIViewController?, animated: Bool) {
        guard configuration != nil else { fail(.notConfigured); return }
        if isPresented, chatController != nil { return }
        if webView == nil || loadFailed { load() }
        guard let w = webView, let from = presenter ?? Self.topViewController() else { return }
        let vc = ChatViewController(webView: w)
        vc.modalPresentationStyle = LiveChatAE.presentationStyle
        vc.presentationController?.delegate = self
        if let sheet = vc.sheetPresentationController { sheet.prefersGrabberVisible = false }
        chatController = vc
        isPresented = true
        LiveChatAEState.shared.isPresented = true
        from.present(vc, animated: animated)
        run("open")
        LiveChatAE.delegate?.liveChatDidPresent()
        LiveChatAE.onPresent?()
    }

    func dismiss(animated: Bool) {
        guard let vc = chatController else { didDismiss(); return }
        vc.presentingViewController?.dismiss(animated: animated) { [weak self] in self?.didDismiss() }
        if vc.presentingViewController == nil { didDismiss() }
    }

    /// The window is gone (our dismiss, or a swipe down): the web view goes back to its parking.
    private func didDismiss() {
        guard isPresented else { return }
        isPresented = false
        chatController = nil
        LiveChatAEState.shared.isPresented = false
        park()
        run("close")
        LiveChatAE.delegate?.liveChatDidDismiss()
        LiveChatAE.onDismiss?()
    }

    /// Behind all the app's views of the key window: alive, invisible, untouchable.
    private func park() {
        guard let w = webView, !isPresented, let window = Self.keyWindow() else { return }
        if parking.superview !== window {
            parking.frame = window.bounds
            window.insertSubview(parking, at: 0)
        }
        w.translatesAutoresizingMaskIntoConstraints = true
        w.frame = parking.bounds
        w.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parking.addSubview(w)
    }

    @objc private func windowDidBecomeKey() {
        if !isPresented, webView != nil, parking.window == nil || webView?.superview == nil { park() }
    }

    static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.sorted { a, _ in a.activationState == .foregroundActive }.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    static func topViewController() -> UIViewController? {
        var top = keyWindow()?.rootViewController
        while let p = top?.presentedViewController, !p.isBeingDismissed { top = p }
        return top
    }

    // MARK: - App lifecycle

    @objc private func appDidEnterBackground() {
        guard let w = webView, pageReady else { return }
        // a few seconds to close the connection before iOS suspends the app
        var task = UIBackgroundTaskIdentifier.invalid
        task = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(task) }
        w.evaluateJavaScript(Script.call("pause")) { _, _ in
            Task { @MainActor in UIApplication.shared.endBackgroundTask(task) }
        }
    }

    @objc private func appWillEnterForeground() {
        if loadFailed { load(); return }
        run("resume")
    }

    // MARK: - Events from the page

    fileprivate func handle(_ event: BridgeEvent) {
        switch event {
        case let .ready(online, _, count):
            pageReady = true
            loadFailed = false
            setOnline(online)
            setUnread(count)
            if isPresented { run("open") }
        case let .status(online):
            setOnline(online)
        case let .message(m):
            LiveChatAE.delegate?.liveChat(didReceive: m)
            LiveChatAE.onMessage?(m)
        case let .unread(n):
            setUnread(n)
        case let .chatStarted(id):
            LiveChatAE.delegate?.liveChat(didStartChat: id)
            LiveChatAE.onChatStarted?(id)
        case let .chatClosed(id):
            LiveChatAE.delegate?.liveChat(didEndChat: id)
            LiveChatAE.onChatEnded?(id)
        case .closeRequested:
            dismiss(animated: true)
        case let .error(e):
            fail(e)
        }
    }

    private func setUnread(_ n: Int) {
        guard n != unread else { return }
        unread = n
        LiveChatAEState.shared.unreadCount = n
        LiveChatAE.delegate?.liveChat(unreadCountDidChange: n)
        LiveChatAE.onUnreadCountChange?(n)
        NotificationCenter.default.post(name: LiveChatAE.unreadCountDidChangeNotification, object: n)
    }

    private func setOnline(_ online: Bool) {
        if LiveChatAEState.shared.agentsOnline != online { LiveChatAEState.shared.agentsOnline = online }
    }

    private func fail(_ e: LiveChatAEError) {
        LiveChatAEState.shared.lastError = e
        LiveChatAE.delegate?.liveChat(didFailWith: e)
        LiveChatAE.onError?(e)
    }

    // MARK: - Links

    fileprivate func open(_ url: URL) {
        let web = url.scheme == "http" || url.scheme == "https"
        if !web {   // mailto:, tel:, whatsapp:... always to the system
            UIApplication.shared.open(url)
            return
        }
        switch LiveChatAE.linkHandling {
        case .external:
            UIApplication.shared.open(url)
        case let .custom(handler):
            handler(url)
        case .inApp:
            guard let from = Self.topViewController() else { UIApplication.shared.open(url); return }
            let safari = SFSafariViewController(url: url)
            safari.modalPresentationStyle = .pageSheet
            from.present(safari, animated: true)
        }
    }

    fileprivate func isChatPage(_ url: URL) -> Bool {
        guard let page = configuration?.chatURL else { return false }
        return url.host == page.host && url.port == page.port && url.path == page.path
    }
}

// MARK: - WebKit

extension ChatSession: WKNavigationDelegate, WKUIDelegate, UIAdaptivePresentationControllerDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        let mainFrame = action.targetFrame?.isMainFrame ?? false
        // frames inside the chat (a video in a knowledge base article) and the chat page itself load here
        if !mainFrame && action.targetFrame != nil { decisionHandler(.allow); return }
        if url.scheme == "about" || (isChatPage(url) && action.navigationType != .linkActivated) {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        open(url)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
            fail(http.statusCode == 404 ? .invalidKey : .http(http.statusCode))
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFailed = true
        fail(.network(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        loadFailed = true
        fail(.network(error.localizedDescription))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        load()   // iOS killed the web process to free memory: start again
    }

    // target="_blank" links and window.open (attachments, images, article links)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) {
        guard let from = Self.topViewController() else { completionHandler(); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        from.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) {
        guard let from = Self.topViewController() else { completionHandler(false); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        from.present(a, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didDismiss()   // swiped down
    }
}

/// WKUserContentController keeps its handlers strongly: this breaks the cycle.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var session: ChatSession?
    init(_ s: ChatSession) { session = s }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = BridgeEvent.parse(message.body) else { return }
        MainActor.assumeIsolated { session?.handle(event) }
    }
}
#endif
