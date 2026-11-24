import Foundation

/// Where and how the chat runs. Pass it to ``LiveChatAE/configure(_:)``.
public struct LiveChatAEConfiguration: Equatable, Sendable {
    /// The widget key of your livechat.ae account: the same `data-key` you put in the
    /// website snippet (Admin › Installation).
    public var key: String
    /// The livechat.ae server. Change it only for a self-hosted or local server.
    public var server: URL
    /// Chat language: `it`, `en`, `es`, `fr`, `de`, `ar` or `ru`. `nil` uses the language set in
    /// your account, then the language of the device.
    public var language: String?
    /// Department that receives the chats started from the app (its name, as in Admin › Departments).
    /// `nil` lets the visitor choose when your account has more than one department.
    public var department: String?

    public init(key: String, server: URL = URL(string: "https://livechat.ae")!, language: String? = nil, department: String? = nil) {
        self.key = key
        self.server = server
        self.language = language
        self.department = department
    }

    /// The page that the SDK opens in its web view.
    public var chatURL: URL? {
        guard !key.isEmpty, var c = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        var path = c.path
        if path.hasSuffix("/") { path.removeLast() }
        c.path = path + "/sdk/chat"
        var q = [URLQueryItem(name: "key", value: key)]
        if let language, !language.isEmpty { q.append(URLQueryItem(name: "lang", value: language)) }
        if let department, !department.isEmpty { q.append(URLQueryItem(name: "department", value: department)) }
        c.queryItems = q
        return c.url
    }
}

/// A message of the conversation, as received by ``LiveChatAEDelegate/liveChat(didReceive:)``.
public struct LiveChatAEMessage: Equatable, Sendable {
    public enum Sender: String, Sendable {
        /// An agent, an AI agent or an automation of your team.
        case agent = "AGENT"
        /// The visitor, that is the user of your app.
        case visitor = "VISITOR"
        /// A notice of the chat (agent joined, chat closed...).
        case system = "SYSTEM"
        case unknown
    }

    public struct Attachment: Equatable, Sendable {
        public let name: String
        public let url: URL?
        public let contentType: String
    }

    public let id: Int64?
    public let sender: Sender
    /// Name of who wrote it (empty for the visitor and for notices).
    public let author: String
    public let text: String
    public let attachment: Attachment?
    public let date: Date?
}

/// What can go wrong. Delivered to ``LiveChatAEDelegate/liveChat(didFailWith:)``.
public enum LiveChatAEError: Error, Equatable, Sendable {
    /// ``LiveChatAE/configure(_:)`` has not been called.
    case notConfigured
    /// The widget key does not exist or the account is not active.
    case invalidKey
    /// The chat page could not be loaded (no network, server down...).
    case network(String)
    /// The server answered with an unexpected HTTP status.
    case http(Int)
    /// The chat settings could not be loaded.
    case configurationFailed
    /// The account turned the chat off for this visitor.
    case disabled
    /// A new chat could not be started.
    case chatStartFailed
    /// Too many chats started from this network in a few minutes.
    case tooManyChats
    /// Any other error reported by the chat.
    case other(String)

    init(code: String) {
        switch code {
        case "config_failed": self = .configurationFailed
        case "disabled": self = .disabled
        case "chat_start_failed": self = .chatStartFailed
        case "too_many_chats": self = .tooManyChats
        case "missing_key": self = .invalidKey
        default: self = .other(code)
        }
    }
}

/// How links and attachments tapped in the chat are opened.
public enum LiveChatAELinkHandling: Sendable {
    /// Inside the app, in a Safari view (default).
    case inApp
    /// Outside the app, in Safari or in the app that handles the link.
    case external
    /// Your code decides: the SDK calls the closure and does nothing else.
    case custom(@Sendable (URL) -> Void)
}
