import LiveChatAE
import SwiftUI
import UserNotifications

@main
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Setup of the chat and of push notifications: what a real app does at launch.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let settings = ExampleSettings.load()
        LiveChatAE.configure(settings.configuration)

        // every event of the chat ends up in the log on screen
        let log = EventLog.shared
        LiveChatAE.onMessage = { m in log.add("message · \(m.sender.rawValue.lowercased())\(m.author.isEmpty ? "" : " · \(m.author)") · \(m.text)") }
        LiveChatAE.onUnreadCountChange = { log.add("unread · \($0)") }
        LiveChatAE.onPresent = { log.add("chat presented") }
        LiveChatAE.onDismiss = { log.add("chat dismissed") }
        LiveChatAE.onChatStarted = { log.add("chat started · \($0.prefix(8))…") }
        LiveChatAE.onChatEnded = { log.add("chat ended · \($0.prefix(8))…") }
        LiveChatAE.onError = { log.add("error · \($0)") }

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        LiveChatAE.setPushToken(deviceToken)
        EventLog.shared.add("push token · \(deviceToken.map { String(format: "%02x", $0) }.joined().prefix(12))…")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // normal in the simulator without a signed build: the chat works the same
        EventLog.shared.add("no push token · \(error.localizedDescription)")
    }

    // a notification arrives while the app is open: no banner if the chat is already on screen
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let ours = LiveChatAE.isLiveChatNotification(notification.request.content.userInfo)
        Task { @MainActor in
            completionHandler(ours && LiveChatAE.isPresented ? [] : [.banner, .sound])
        }
    }

    // the user tapped a notification: if it is about the chat, open it
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            LiveChatAE.handleNotification(userInfo)
            completionHandler()
        }
    }
}

/// Server and key of the example, remembered between launches.
struct ExampleSettings {
    var server: String
    var key: String

    static func load() -> ExampleSettings {
        let d = UserDefaults.standard
        return ExampleSettings(server: d.string(forKey: "server") ?? "http://localhost:8080",
                               key: d.string(forKey: "key") ?? "demo")
    }

    func save() {
        UserDefaults.standard.set(server, forKey: "server")
        UserDefaults.standard.set(key, forKey: "key")
    }

    var configuration: LiveChatAEConfiguration {
        LiveChatAEConfiguration(key: key, server: URL(string: server) ?? URL(string: "https://livechat.ae")!)
    }
}

/// The last events of the chat, newest first.
@MainActor
final class EventLog: ObservableObject {
    static let shared = EventLog()
    struct Entry: Identifiable { let id = UUID(); let time: Date; let text: String }
    @Published private(set) var entries: [Entry] = []

    nonisolated func add(_ text: String) {
        Task { @MainActor in
            self.entries.insert(Entry(time: Date(), text: text), at: 0)
            if self.entries.count > 50 { self.entries.removeLast() }
        }
    }
}
