import LiveChatAE
import SwiftUI

/// A small "shop" screen with everything the SDK can do.
struct ContentView: View {
    @ObservedObject private var chat = LiveChatAEState.shared
    @ObservedObject private var log = EventLog.shared
    @State private var settings = ExampleSettings.load()
    @State private var name = "Sara Rossi"
    @State private var email = "sara@example.com"
    @State private var plan = "Gold"
    @State private var linksOutside = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Agents online", value: chat.agentsOnline ? "yes" : "no")
                    LabeledContent("Unread", value: "\(chat.unreadCount)")
                    Button("Open chat") { LiveChatAE.present() }
                        .accessibilityIdentifier("openChat")
                } header: {
                    Text("Chat")
                }

                Section {
                    TextField("Name", text: $name).textContentType(.name)
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Plan (custom field)", text: $plan)
                    Button("Send to the chat") {
                        LiveChatAE.setVisitor(name: name, email: email)
                        LiveChatAE.setCustomFields(["plan": plan, "platform": "iOS example"])
                        EventLog.shared.add("visitor set · \(name)")
                    }
                    Button("Forget visitor (sign out)", role: .destructive) {
                        LiveChatAE.identify(token: nil)
                        LiveChatAE.reset()
                        EventLog.shared.add("visitor reset")
                    }
                } header: {
                    Text("Signed-in user")
                }

                Section {
                    Toggle("Open links in Safari", isOn: $linksOutside)
                        .onChange(of: linksOutside) { outside in
                            LiveChatAE.linkHandling = outside ? .external : .inApp
                        }
                } header: {
                    Text("Links and attachments")
                }

                Section {
                    TextField("Server", text: $settings.server)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    TextField("Widget key", text: $settings.key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Apply") {
                        settings.save()
                        LiveChatAE.configure(settings.configuration)
                        EventLog.shared.add("configured · \(settings.key) @ \(settings.server)")
                    }
                } header: {
                    Text("Account")
                }

                Section {
                    if log.entries.isEmpty { Text("Nothing yet").foregroundStyle(.secondary) }
                    ForEach(log.entries) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.text).font(.callout)
                            Text(e.time, style: .time).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Events")
                }
            }
            .navigationTitle("Chat demo")
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }   // room for the chat button
        }
        .overlay(alignment: .bottomTrailing) {
            LiveChatAEChatButton().padding(20)
        }
    }
}
