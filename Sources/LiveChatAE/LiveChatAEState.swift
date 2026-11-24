#if canImport(UIKit) && canImport(WebKit) && canImport(Combine)
import Combine
import Foundation

/// The chat state as an `ObservableObject`, for SwiftUI views:
///
/// ```swift
/// @ObservedObject var chat = LiveChatAEState.shared
/// Text("Unread: \(chat.unreadCount)")
/// ```
@MainActor
public final class LiveChatAEState: ObservableObject {
    public static let shared = LiveChatAEState()

    /// Agent messages the visitor has not seen yet.
    @Published public internal(set) var unreadCount = 0
    /// `true` while the chat window is on screen.
    @Published public internal(set) var isPresented = false
    /// `true` while at least one agent can answer (as last reported by the chat).
    @Published public internal(set) var agentsOnline = false
    /// The last error, if any.
    @Published public internal(set) var lastError: LiveChatAEError?

    private init() {}
}
#endif
