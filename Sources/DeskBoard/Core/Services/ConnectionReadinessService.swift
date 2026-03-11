import Foundation
import os.log

actor ConnectionReadinessService {
    static let shared = ConnectionReadinessService()

    private let log = Logger(subsystem: "com.deskboard", category: "ConnectionReadiness")
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 8
        session = URLSession(configuration: config)
    }

    static func isPlaceholderURL(_ raw: String) -> Bool {
        let value = raw.trimmed.lowercased()
        guard !value.isEmpty else { return false }
        return value.contains("your-worker.workers.dev")
            || value.contains("<your-subdomain>")
            || value.contains("example.com")
            || value.contains("placeholder")
    }

    func evaluate() async -> ConnectionReadiness {
        let pushWakeEnabled = AppConfiguration.pushWakeEnabled
        let relayConfigured = AppConfiguration.backgroundRelayEnabled && AppConfiguration.backgroundRelayBaseURL != nil
        let apnsTokenReady = AppConfiguration.pushToken?.trimmed.isEmpty == false
        let gatewayURL = AppConfiguration.pushGatewayBaseURL
        let gatewayConfigured = gatewayURL != nil

        let health: GatewayHealthResult?
        if let gatewayURL, pushWakeEnabled {
            health = await checkGatewayHealth(baseURL: gatewayURL)
        } else {
            health = nil
        }

        let context = ReadinessContext(
            pushWakeEnabled: pushWakeEnabled,
            relayConfigured: relayConfigured,
            apnsTokenReady: apnsTokenReady,
            gatewayConfigured: gatewayConfigured,
            gatewayLooksPlaceholder: Self.isPlaceholderURL(AppConfiguration.pushGatewayURL),
            health: health
        )
        return Self.buildReadiness(from: context)
    }

    nonisolated static func buildReadiness(from context: ReadinessContext) -> ConnectionReadiness {
        var notes: [String] = []
        var blockingErrorCode: String?

        let gatewayReachable = context.health?.reachable ?? false
        let apnsTopicMatchesBundle = context.health?.apnsTopicMatchesBundle
        let gatewayAPNSConfigured = context.health?.apnsConfigured

        func setBlocking(_ code: String, _ note: String) {
            if blockingErrorCode == nil {
                blockingErrorCode = code
            }
            notes.append(note)
        }

        if context.pushWakeEnabled {
            if !context.apnsTokenReady {
                setBlocking("apns_token_missing", "APNs token is not registered yet.")
            }
            if !context.gatewayConfigured {
                setBlocking("gateway_missing", "Gateway URL is missing.")
            } else if context.gatewayLooksPlaceholder {
                setBlocking("gateway_placeholder_url", "Gateway URL still contains a placeholder value.")
            } else {
                if !gatewayReachable {
                    let code = context.health?.errorCode ?? "gateway_unreachable"
                    setBlocking(code, "Gateway is unreachable or returned an invalid response.")
                }
                if let apnsConfigured = gatewayAPNSConfigured, !apnsConfigured {
                    setBlocking("gateway_apns_not_configured", "Gateway APNs credentials are not configured.")
                }
                if let topicMatch = apnsTopicMatchesBundle, !topicMatch {
                    setBlocking("apns_topic_mismatch", "Gateway APNs topic does not match this app bundle ID.")
                }
            }
        }

        if !context.relayConfigured {
            notes.append("Mac relay is not configured.")
        }

        if let healthError = context.health?.errorCode, healthError != blockingErrorCode {
            notes.append("Gateway check error: \(healthError)")
        }

        let overallStatus: ConnectionReadinessStatus = {
            if context.pushWakeEnabled {
                let wakeReady = context.apnsTokenReady
                    && context.gatewayConfigured
                    && !context.gatewayLooksPlaceholder
                    && gatewayReachable
                    && (gatewayAPNSConfigured ?? true)
                    && (apnsTopicMatchesBundle ?? true)
                return wakeReady ? .ready : .misconfigured
            }
            if context.relayConfigured {
                return .partial
            }
            return .misconfigured
        }()

        return ConnectionReadiness(
            apnsTokenReady: context.apnsTokenReady,
            gatewayConfigured: context.gatewayConfigured,
            gatewayReachable: gatewayReachable,
            apnsTopicMatchesBundle: apnsTopicMatchesBundle,
            relayConfigured: context.relayConfigured,
            overallStatus: overallStatus,
            blockingErrorCode: blockingErrorCode,
            notes: notes
        )
    }

    private func checkGatewayHealth(baseURL: URL) async -> GatewayHealthResult {
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("health"))
            request.httpMethod = "GET"
            if let apiKey = AppConfiguration.pushGatewayAPIKey?.trimmed, !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "x-deskboard-key")
            }

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return GatewayHealthResult(
                    reachable: false,
                    apnsTopicMatchesBundle: nil,
                    apnsConfigured: nil,
                    errorCode: "bad_gateway_response"
                )
            }
            guard (200...299).contains(http.statusCode) else {
                return GatewayHealthResult(
                    reachable: false,
                    apnsTopicMatchesBundle: nil,
                    apnsConfigured: nil,
                    errorCode: "gateway_http_\(http.statusCode)"
                )
            }

            let payload = try? JSONDecoder().decode(PushGatewayHealthPayload.self, from: data)
            let bundleID = Bundle.main.bundleIdentifier?.trimmed
            let apnsTopic = payload?.apnsTopic?.trimmed
            let topicMatch: Bool? = {
                guard let bundleID, !bundleID.isEmpty else { return nil }
                guard let apnsTopic, !apnsTopic.isEmpty else { return nil }
                return apnsTopic == bundleID
            }()

            return GatewayHealthResult(
                reachable: true,
                apnsTopicMatchesBundle: topicMatch,
                apnsConfigured: payload?.configured,
                errorCode: nil
            )
        } catch {
            log.error("READY-001 Gateway health check failed: \(String(describing: error), privacy: .public)")
            return GatewayHealthResult(
                reachable: false,
                apnsTopicMatchesBundle: nil,
                apnsConfigured: nil,
                errorCode: "gateway_request_failed"
            )
        }
    }
}

nonisolated struct GatewayHealthResult: Sendable {
    let reachable: Bool
    let apnsTopicMatchesBundle: Bool?
    let apnsConfigured: Bool?
    let errorCode: String?
}

nonisolated struct ReadinessContext: Sendable {
    let pushWakeEnabled: Bool
    let relayConfigured: Bool
    let apnsTokenReady: Bool
    let gatewayConfigured: Bool
    let gatewayLooksPlaceholder: Bool
    let health: GatewayHealthResult?
}

private struct PushGatewayHealthPayload: Codable {
    let ok: Bool?
    let service: String?
    let version: String?
    let apnsTopic: String?
    let apnsUseSandbox: Bool?
    let configured: Bool?
}
