import XCTest
@testable import DeskBoard

final class ConnectionReadinessTests: XCTestCase {

    func testPlaceholderURLDetection() {
        XCTAssertTrue(ConnectionReadinessService.isPlaceholderURL("https://your-worker.workers.dev"))
        XCTAssertTrue(ConnectionReadinessService.isPlaceholderURL("https://example.com"))
        XCTAssertFalse(ConnectionReadinessService.isPlaceholderURL("https://deskboard-push-gateway.company.workers.dev"))
    }

    func testBackupSettingsLegacyDecodeCompatibility() throws {
        let legacy: [String: Any] = [
            "hapticEnabled": true,
            "silentReceiver": false,
            "defaultColumns": 3,
            "autoReconnect": true,
            "timeoutSeconds": 12.0,
            "retryCount": 1
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(BackupSettings.self, from: data)

        XCTAssertTrue(decoded.hapticEnabled)
        XCTAssertTrue(decoded.autoReconnect)
        XCTAssertNil(decoded.pushWakeEnabled)
        XCTAssertNil(decoded.pushGatewayURL)
        XCTAssertNil(decoded.backgroundRelayEnabled)
        XCTAssertNil(decoded.backgroundRelayURL)
    }

    func testBackupSettingsRoundTripWithNetworkFields() throws {
        let settings = BackupSettings(
            hapticEnabled: true,
            silentReceiver: false,
            defaultColumns: 3,
            autoReconnect: true,
            timeoutSeconds: 12,
            retryCount: 1,
            pushWakeEnabled: true,
            pushGatewayURL: "https://gateway.workers.dev",
            backgroundRelayEnabled: true,
            backgroundRelayURL: "http://192.168.1.20:7788"
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(BackupSettings.self, from: data)

        XCTAssertEqual(decoded.pushWakeEnabled, true)
        XCTAssertEqual(decoded.pushGatewayURL, "https://gateway.workers.dev")
        XCTAssertEqual(decoded.backgroundRelayEnabled, true)
        XCTAssertEqual(decoded.backgroundRelayURL, "http://192.168.1.20:7788")
    }

    func testReadinessGatewayMissingIsMisconfigured() {
        let context = ReadinessContext(
            pushWakeEnabled: true,
            relayConfigured: false,
            apnsTokenReady: true,
            gatewayConfigured: false,
            gatewayLooksPlaceholder: false,
            health: nil
        )

        let readiness = ConnectionReadinessService.buildReadiness(from: context)
        XCTAssertEqual(readiness.overallStatus, .misconfigured)
        XCTAssertEqual(readiness.blockingErrorCode, "gateway_missing")
    }

    func testReadinessTopicMismatchIsMisconfigured() {
        let health = GatewayHealthResult(
            reachable: true,
            apnsTopicMatchesBundle: false,
            apnsConfigured: true,
            errorCode: nil
        )
        let context = ReadinessContext(
            pushWakeEnabled: true,
            relayConfigured: true,
            apnsTokenReady: true,
            gatewayConfigured: true,
            gatewayLooksPlaceholder: false,
            health: health
        )

        let readiness = ConnectionReadinessService.buildReadiness(from: context)
        XCTAssertEqual(readiness.overallStatus, .misconfigured)
        XCTAssertEqual(readiness.blockingErrorCode, "apns_topic_mismatch")
    }

    func testReadinessReadyWhenWakePrerequisitesAreValid() {
        let health = GatewayHealthResult(
            reachable: true,
            apnsTopicMatchesBundle: true,
            apnsConfigured: true,
            errorCode: nil
        )
        let context = ReadinessContext(
            pushWakeEnabled: true,
            relayConfigured: false,
            apnsTokenReady: true,
            gatewayConfigured: true,
            gatewayLooksPlaceholder: false,
            health: health
        )

        let readiness = ConnectionReadinessService.buildReadiness(from: context)
        XCTAssertEqual(readiness.overallStatus, .ready)
        XCTAssertNil(readiness.blockingErrorCode)
    }

    func testReadinessRelayOnlyIsPartial() {
        let context = ReadinessContext(
            pushWakeEnabled: false,
            relayConfigured: true,
            apnsTokenReady: false,
            gatewayConfigured: false,
            gatewayLooksPlaceholder: false,
            health: nil
        )

        let readiness = ConnectionReadinessService.buildReadiness(from: context)
        XCTAssertEqual(readiness.overallStatus, .partial)
        XCTAssertNil(readiness.blockingErrorCode)
    }
}
