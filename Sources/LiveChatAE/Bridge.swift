import Foundation

/// The events that the chat page (widget.js in "sdk" mode) posts to the app.
enum BridgeEvent: Equatable {
    case ready(online: Bool, chatId: String?, unread: Int)
    case status(online: Bool)
    case message(LiveChatAEMessage)
    case unread(Int)
    case chatStarted(chatId: String)
    case chatClosed(chatId: String)
    case closeRequested
    case error(LiveChatAEError)

    /// Reads what WKScriptMessage.body gives (a dictionary from a JavaScript object).
    static func parse(_ body: Any) -> BridgeEvent? {
        guard let d = body as? [String: Any], let type = d["type"] as? String else { return nil }
        switch type {
        case "ready":
            return .ready(online: d["online"] as? Bool ?? false, chatId: d["chatId"] as? String, unread: int(d["unread"]) ?? 0)
        case "status":
            return .status(online: d["online"] as? Bool ?? false)
        case "unread":
            return .unread(max(0, int(d["count"]) ?? 0))
        case "chat_started":
            return .chatStarted(chatId: d["chatId"] as? String ?? "")
        case "chat_closed":
            return .chatClosed(chatId: d["chatId"] as? String ?? "")
        case "close_requested":
            return .closeRequested
        case "error":
            return .error(LiveChatAEError(code: d["code"] as? String ?? "unknown"))
        case "message":
            var attachment: LiveChatAEMessage.Attachment?
            if let a = d["attachment"] as? [String: Any] {
                attachment = .init(name: a["name"] as? String ?? "",
                                   url: (a["url"] as? String).flatMap(URL.init(string:)),
                                   contentType: a["contentType"] as? String ?? "")
            }
            let id = (d["id"] as? NSNumber)?.int64Value
            return .message(LiveChatAEMessage(
                id: id,
                sender: LiveChatAEMessage.Sender(rawValue: d["sender"] as? String ?? "") ?? .unknown,
                author: d["author"] as? String ?? "",
                text: d["text"] as? String ?? "",
                attachment: attachment,
                date: date(d["createdAt"])))
        default:
            return nil
        }
    }

    private static func int(_ v: Any?) -> Int? {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) }
        return nil
    }

    /// The server sends ISO-8601 dates ("2026-11-24T06:30:00.123456Z") or epoch seconds.
    static func date(_ v: Any?) -> Date? {
        if let n = v as? NSNumber { return Date(timeIntervalSince1970: n.doubleValue) }
        guard let s = v as? String else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

/// JavaScript that the app runs in the chat page: calls to the widget API (window.LiveChatAE).
enum Script {
    /// `window.LiveChatAE.name(argument)`, or a queued call if the widget is not loaded yet.
    static func call(_ name: String, _ argument: Any? = nil) -> String {
        let arg = argument.map(json) ?? "undefined"
        return "(function(){var a=\(arg);var w=window.LiveChatAE;"
            + "if(w&&!Array.isArray(w)&&typeof w[\(json(name))]==='function'){w[\(json(name))](a);}"
            + "else{(window.LiveChatAE=window.LiveChatAE||[]).push([\(json(name)),a]);}})();"
    }

    /// The calls that run before the widget loads (window.LiveChatAE as a queue).
    static func queue(_ calls: [(String, Any)]) -> String {
        let items = calls.map { "[\(json($0.0)),\(json($0.1))]" }.joined(separator: ",")
        return "window.LiveChatAE=[\(items)];"
    }

    /// A JSON literal: safe to put in JavaScript whatever the text contains.
    static func json(_ value: Any) -> String {
        if let s = value as? String {
            // a string alone is not valid top-level JSON for every Foundation version: wrap it
            let data = (try? JSONSerialization.data(withJSONObject: [s])) ?? Data("[\"\"]".utf8)
            var out = String(decoding: data, as: UTF8.self)
            out.removeFirst(); out.removeLast()
            return escapeLineSeparators(out)
        }
        if let b = value as? Bool { return b ? "true" : "false" }
        if let n = value as? NSNumber { return n.stringValue }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else { return "null" }
        return escapeLineSeparators(String(decoding: data, as: UTF8.self))
    }

    /// U+2028 and U+2029 are valid in JSON but end a line in older JavaScript engines.
    private static func escapeLineSeparators(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}

enum PushToken {
    /// The APNs device token as the hexadecimal text that APNs expects.
    static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }
}
