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

    func testActionResultRoundTrip() throws {
        let payload = ActionExecutionReport(
            commandID: UUID(),
            status: .queued,
            detail: "Queued until receiver returns to foreground",
            target: "ios_receiver",
            queuePosition: 3
        )
        let message = CommandMessage(
            type: .actionResult,
            payload: .actionResult(payload),
            senderID: "receiver-device"
        )
        let data = try encoder.encode(message)
        let decoded = try encoder.decode(data)

        XCTAssertEqual(decoded.type, .actionResult)
        if case .actionResult(let report) = decoded.payload {
            XCTAssertEqual(report.commandID, payload.commandID)
            XCTAssertEqual(report.status, .queued)
            XCTAssertEqual(report.queuePosition, 3)
            XCTAssertEqual(report.target, "ios_receiver")
        } else {
            XCTFail("Expected .actionResult payload")
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

    func testLegacyV1MessageDecodesWithDefaults() throws {
        let message = CommandMessage(
            type: .action,
            payload: .buttonAction(.mediaPlay),
            senderID: "legacy-device"
        )
        let data = try encoder.encode(message)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        json.removeValue(forKey: "protocolVersion")
        json.removeValue(forKey: "originDeviceUUID")
        json.removeValue(forKey: "traceID")
        json.removeValue(forKey: "deliveryPolicy")
        json.removeValue(forKey: "ttlSeconds")
        json.removeValue(forKey: "targetPolicy")
        json.removeValue(forKey: "backgroundFallback")
        json.removeValue(forKey: "attempt")
        json.removeValue(forKey: "maxAttempts")

        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try encoder.decode(legacyData)

        XCTAssertEqual(decoded.protocolVersion, 1)
        XCTAssertEqual(decoded.deliveryPolicy, .atLeastOnce)
        XCTAssertEqual(decoded.attempt, 1)
        XCTAssertEqual(decoded.maxAttempts, 1)
        XCTAssertEqual(decoded.traceID, decoded.id.uuidString)
    }

    func testActionReportLegacyDecodesWithDefaults() throws {
        let report = ActionExecutionReport(
            commandID: UUID(),
            status: .success,
            detail: "Done"
        )
        let data = try JSONEncoder().encode(report)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "executor")
        json.removeValue(forKey: "errorCode")
        json.removeValue(forKey: "attempt")
        json.removeValue(forKey: "latencyMs")

        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(ActionExecutionReport.self, from: legacyData)

        XCTAssertEqual(decoded.executor, .iosReceiver)
        XCTAssertEqual(decoded.attempt, 1)
        XCTAssertNil(decoded.errorCode)
    }
}
