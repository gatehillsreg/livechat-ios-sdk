# Changelog

## 1.0.0 — 2026-11-24

First release.

- The livechat.ae chat in a `WKWebView`, with the same settings, forms, departments, languages and knowledge base as the website chat
- `LiveChatAE.configure`, `present`, `dismiss`, `setVisitor`, `setCustomFields`, `identify`, `setDepartment`, `reset`
- Events through `LiveChatAEDelegate`, closures, `LiveChatAEState` (SwiftUI) and `unreadCountDidChangeNotification`
- Ready-made chat buttons with the unread badge: `LiveChatAEButton` (UIKit) and `LiveChatAEChatButton` (SwiftUI)
- Links and attachments in the app, in Safari or handled by the app
- Push notifications through the `chat.agent_message` webhook: `setPushToken`, `handleNotification`
- Swift Package Manager and CocoaPods
