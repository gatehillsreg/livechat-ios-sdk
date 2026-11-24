import Foundation

/// Events of the chat. Every method is optional. All calls happen on the main thread.
///
/// The same events are also available as closures on ``LiveChatAE`` (`onMessage`,
/// `onUnreadCountChange`...), handy in SwiftUI.
@MainActor
public protocol LiveChatAEDelegate: AnyObject {
    /// A new message arrived (from an agent, from the visitor or a notice), also while the
    /// chat window is closed, as long as the app is in the foreground.
    func liveChat(didReceive message: LiveChatAEMessage)
    /// The number of agent messages that the visitor has not seen yet changed.
    func liveChat(unreadCountDidChange count: Int)
    /// The chat window was shown.
    func liveChatDidPresent()
    /// The chat window was closed (by your code, by the visitor or with a swipe).
    func liveChatDidDismiss()
    /// A conversation started (the visitor wrote the first message, reopened a closed chat,
    /// or an agent invited them).
    func liveChat(didStartChat chatId: String)
    /// The conversation ended (closed by the agent, the visitor or for inactivity).
    func liveChat(didEndChat chatId: String)
    /// Something went wrong.
    func liveChat(didFailWith error: LiveChatAEError)
}

public extension LiveChatAEDelegate {
    func liveChat(didReceive message: LiveChatAEMessage) {}
    func liveChat(unreadCountDidChange count: Int) {}
    func liveChatDidPresent() {}
    func liveChatDidDismiss() {}
    func liveChat(didStartChat chatId: String) {}
    func liveChat(didEndChat chatId: String) {}
    func liveChat(didFailWith error: LiveChatAEError) {}
}
