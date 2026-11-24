import Foundation
import XCTest
@testable import LiveChatAE

final class LiveChatAETests: XCTestCase {
    func testChatURL() {
        let c = LiveChatAEConfiguration(key: "abc_123", server: URL(string: "https://livechat.ae/")!, language: "it", department: "Vendite & Co")
        XCTAssertEqual(c.chatURL?.absoluteString, "https://livechat.ae/sdk/chat?key=abc_123&lang=it&department=Vendite%20%26%20Co")
        let local = LiveChatAEConfiguration(key: "demo", server: URL(string: "http://localhost:8081")!)
        XCTAssertEqual(local.chatURL?.absoluteString, "http://localhost:8081/sdk/chat?key=demo")
        XCTAssertNil(LiveChatAEConfiguration(key: "").chatURL)
    }

    func testParseMessage() {
        let body: [String: Any] = [
            "type": "message", "id": NSNumber(value: 42), "sender": "AGENT", "author": "Sara", "text": "Ciao!",
            "createdAt": "2026-11-24T06:30:00.123456Z",
            "attachment": ["name": "fattura.pdf", "url": "https://livechat.ae/api/visitor/files/x?chatId=c&token=t", "contentType": "application/pdf"]
        ]
        guard case let .message(m)? = BridgeEvent.parse(body) else { return XCTFail("not a message") }
        XCTAssertEqual(m.id, 42)
        XCTAssertEqual(m.sender, .agent)
        XCTAssertEqual(m.author, "Sara")
        XCTAssertEqual(m.text, "Ciao!")
        XCTAssertEqual(m.attachment?.name, "fattura.pdf")
        XCTAssertEqual(m.attachment?.url?.host, "livechat.ae")
        XCTAssertEqual(m.date.map { Int($0.timeIntervalSince1970) }, 1_795_501_800)
    }

    func testParseOtherEvents() {
        XCTAssertEqual(BridgeEvent.parse(["type": "unread", "count": NSNumber(value: 3)]), .unread(3))
        XCTAssertEqual(BridgeEvent.parse(["type": "unread", "count": NSNumber(value: -1)]), .unread(0))
        XCTAssertEqual(BridgeEvent.parse(["type": "chat_started", "chatId": "c1"]), .chatStarted(chatId: "c1"))
        XCTAssertEqual(BridgeEvent.parse(["type": "chat_closed", "chatId": "c1"]), .chatClosed(chatId: "c1"))
        XCTAssertEqual(BridgeEvent.parse(["type": "close_requested"]), .closeRequested)
        XCTAssertEqual(BridgeEvent.parse(["type": "status", "online": true]), .status(online: true))
        XCTAssertEqual(BridgeEvent.parse(["type": "ready", "online": false, "unread": NSNumber(value: 2)]),
                       .ready(online: false, chatId: nil, unread: 2))
        XCTAssertEqual(BridgeEvent.parse(["type": "error", "code": "too_many_chats"]), .error(.tooManyChats))
        XCTAssertEqual(BridgeEvent.parse(["type": "error", "code": "boh"]), .error(.other("boh")))
        XCTAssertNil(BridgeEvent.parse(["type": "unknown"]))
        XCTAssertNil(BridgeEvent.parse("not a dictionary"))
    }

    func testScriptsAreSafeJavaScript() {
        // quotes, backslashes, a closing script tag and a line separator stay inside the string
        let hostile = "Sara \"</script>\\ \u{2028} ' end"
        let js = Script.call("identify", hostile)
        let expected = "var a=\"Sara \\\"<\\/script>\\\\ \\u2028 ' end\";"
        XCTAssertTrue(js.contains(expected), js)
        XCTAssertFalse(js.contains("\u{2028}"))
        XCTAssertEqual(Script.json(["name": "Sara", "email": "s@x.it"]), #"{"email":"s@x.it","name":"Sara"}"#)
        XCTAssertEqual(Script.queue([("setVisitor", ["name": "Sara"]), ("identify", "tok")]),
                       #"window.LiveChatAE=[["setVisitor",{"name":"Sara"}],["identify","tok"]];"#)
        XCTAssertTrue(Script.call("open").contains("var a=undefined;"))
    }

    func testPushTokenHex() {
        XCTAssertEqual(PushToken.hex(Data([0x00, 0xab, 0x10, 0xff])), "00ab10ff")
    }
}
