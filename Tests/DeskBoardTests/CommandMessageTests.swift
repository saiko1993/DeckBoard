import XCTest
@testable import DeskBoard

final class CommandMessageTests: XCTestCase {

    private let encoder = CommandEncoder()

    // MARK: - Round-trip encoding

    func testButtonActionRoundTrip() throws {
        let message = CommandMessage(
            type: .action,
            payload: .buttonAction(.mediaPlay),
            senderID: "iPhone-Test"
        )
        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        XCTAssertEqual(decoded.type, .action)
        XCTAssertEqual(decoded.senderID, "iPhone-Test")
        if case .buttonAction(let action) = decoded.payload {
            XCTAssertEqual(action, .mediaPlay)
        } else {
            XCTFail("Expected .buttonAction payload")
        }
    }

    func testPairingRequestRoundTrip() throws {
        let message = CommandMessage(
            type: .pairingRequest,
            payload: .pairingRequest(pairingCode: "123456", deviceName: "iPhone", deviceRole: "sender"),
            senderID: "Device-A"
        )
        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        if case .pairingRequest(let code, let name, let role) = decoded.payload {
            XCTAssertEqual(code, "123456")
            XCTAssertEqual(name, "iPhone")
            XCTAssertEqual(role, "sender")
        } else {
            XCTFail("Expected .pairingRequest payload")
        }
    }

    func testPairingApprovalRoundTrip() throws {
        let message = CommandMessage(
            type: .pairingApproval,
            payload: .pairingApproval(deviceName: "iPad"),
            senderID: "iPad"
        )
        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        if case .pairingApproval(let name) = decoded.payload {
            XCTAssertEqual(name, "iPad")
        } else {
            XCTFail("Expected .pairingApproval payload")
        }
    }

    func testHeartbeatRoundTrip() throws {
        let message = CommandMessage(
            type: .heartbeat,
            payload: .heartbeat,
            senderID: "device"
        )
        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        XCTAssertEqual(decoded.type, .heartbeat)
        if case .heartbeat = decoded.payload {
            // OK
        } else {
            XCTFail("Expected .heartbeat payload")
        }
    }

    func testURLActionRoundTrip() throws {
        let url = "https://example.com/test"
        let message = CommandMessage(
            type: .action,
            payload: .buttonAction(.openURL(url: url)),
            senderID: "sender"
        )
        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        if case .buttonAction(let action) = decoded.payload,
           case .openURL(let decodedURL) = action {
            XCTAssertEqual(decodedURL, url)
        } else {
            XCTFail("Expected .openURL action")
        }
    }

    func testSendTextRoundTrip() throws {
        let text = "Hello, world! 👋"
        let message = CommandMessage(
            type: .action,
            payload: .buttonAction(.sendText(text: text)),
            senderID: "sender"
        )
        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        if case .buttonAction(let action) = decoded.payload,
           case .sendText(let decodedText) = action {
            XCTAssertEqual(decodedText, text)
        } else {
            XCTFail("Expected .sendText action")
        }
    }

    // MARK: - CommandMessage properties

    func testMessageHasUniqueIDs() {
        let m1 = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: "x")
        let m2 = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: "x")
        XCTAssertNotEqual(m1.id, m2.id)
    }

    func testMessageTimestamp() {
        let before = Date()
        let message = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: "x")
        let after = Date()
        XCTAssertGreaterThanOrEqual(message.timestamp, before)
        XCTAssertLessThanOrEqual(message.timestamp, after)
    }
}