#if canImport(UIKit) && canImport(WebKit)
import UIKit

/// livechat.ae chat for your iPhone and iPad app.
///
/// ```swift
/// LiveChatAE.configure(key: "YOUR-WIDGET-KEY")
/// LiveChatAE.setVisitor(name: "Sara Rossi", email: "sara@example.com")
/// LiveChatAE.present()
/// ```
///
/// The chat is the same one your website visitors see, with the same settings, forms,
/// departments, languages and knowledge base. Everything runs on the main thread.
@MainActor
public enum LiveChatAE {
    /// Version of the SDK. The livechat.ae super admin sees it in the Versions tab.
    public static let version = "1.0.0"

    // MARK: Events

    /// Receives the chat events. Kept weak.
    public static weak var delegate: LiveChatAEDelegate?
    /// A new message arrived (agent, visitor or notice).
    public static var onMessage: ((LiveChatAEMessage) -> Void)?
    /// The number of unread agent messages changed.
    public static var onUnreadCountChange: ((Int) -> Void)?
    /// The chat window was shown.
    public static var onPresent: (() -> Void)?
    /// The chat window was closed.
    public static var onDismiss: (() -> Void)?
    /// A conversation started.
    public static var onChatStarted: ((String) -> Void)?
    /// A conversation ended.
    public static var onChatEnded: ((String) -> Void)?
    /// Something went wrong.
    public static var onError: ((LiveChatAEError) -> Void)?

    /// Posted on the main thread when ``unreadCount`` changes; `object` is the new count (`Int`).
    public static let unreadCountDidChangeNotification = Notification.Name("LiveChatAEUnreadCountDidChange")

    // MARK: Settings

    /// How links and attachments tapped in the chat open. Default: ``LiveChatAELinkHandling/inApp``.
    public static var linkHandling: LiveChatAELinkHandling = .inApp
    /// How the chat window is presented. Default: `.pageSheet` (a sheet on iPhone, a centered
    /// window on iPad). Use `.fullScreen` for a full-screen chat.
    public static var presentationStyle: UIModalPresentationStyle = .pageSheet

    // MARK: State

    /// `true` after ``configure(_:)``.
    public static var isConfigured: Bool { ChatSession.shared.configuration != nil }
    /// The current configuration.
    public static var configuration: LiveChatAEConfiguration? { ChatSession.shared.configuration }
    /// Agent messages the visitor has not seen yet.
    public static var unreadCount: Int { ChatSession.shared.unread }
    /// `true` while the chat window is on screen.
    public static var isPresented: Bool { ChatSession.shared.isPresented }

    // MARK: Setup

    /// Sets up the chat. Call it once at launch (for example in `application(_:didFinishLaunchingWithOptions:)`
    /// or in the `init()` of your SwiftUI `App`): the chat loads in the background, so that messages
    /// and the unread count arrive even before the visitor opens it.
    public static func configure(key: String, server: URL = URL(string: "https://livechat.ae")!,
                                 language: String? = nil, department: String? = nil) {
        configure(LiveChatAEConfiguration(key: key, server: server, language: language, department: department))
    }

    /// Sets up the chat. Calling it again with different values reloads the chat.
    public static func configure(_ configuration: LiveChatAEConfiguration) {
        ChatSession.shared.configure(configuration)
    }

    // MARK: Visitor

    /// Name and email of the signed-in user: they fill the pre-chat form and are used for
    /// new chats when the form does not ask for them.
    public static func setVisitor(name: String?, email: String?) {
        ChatSession.shared.setVisitor(name: name, email: email)
    }

    /// Custom fields shown to agents next to the chat (up to 20; keys up to 40 characters,
    /// values up to 200). Same as `LiveChatAE.setVariables` on the website.
    public static func setCustomFields(_ fields: [String: String]) {
        ChatSession.shared.setCustomFields(fields)
    }

    /// The identity token signed by your server for the signed-in user (same as
    /// `LiveChatAE.identify(token)` on the website); `nil` to remove it, for example at logout.
    public static func identify(token: String?) {
        ChatSession.shared.identify(token)
    }

    /// Department for the next chats (its name). `nil` lets the visitor choose.
    public static func setDepartment(_ name: String?) {
        ChatSession.shared.setDepartment(name)
    }

    /// Forgets the visitor and the conversation on this device, for example when the user
    /// signs out of your app. The next chat starts from scratch.
    public static func reset() {
        ChatSession.shared.reset()
    }

    // MARK: Chat window

    /// Shows the chat. Without `viewController`, the SDK presents it from the top-most view
    /// controller of the key window.
    public static func present(from viewController: UIViewController? = nil, animated: Bool = true) {
        ChatSession.shared.present(from: viewController, animated: animated)
    }

    /// Closes the chat window. The conversation goes on: new messages keep arriving.
    public static func dismiss(animated: Bool = true) {
        ChatSession.shared.dismiss(animated: animated)
    }

    // MARK: Push notifications

    /// The APNs device token of the app, from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    /// livechat.ae sends it to your server in the `chat.agent_message` webhook, which sends the push.
    /// `nil` stops the notifications for this device.
    public static func setPushToken(_ deviceToken: Data?) {
        ChatSession.shared.setPushToken(deviceToken.map(PushToken.hex))
    }

    /// `true` if the notification was sent by your server for a livechat.ae chat
    /// (its payload contains the `livechatae` key).
    public static func isLiveChatNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        userInfo["livechatae"] != nil
    }

    /// Opens the chat if the notification is a livechat.ae one. Call it when the user taps
    /// a notification; returns `false` (and does nothing) for your other notifications.
    @discardableResult
    public static func handleNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard isLiveChatNotification(userInfo) else { return false }
        present()
        return true
    }
}
#endif
