import Foundation

nonisolated enum ConnectionReadinessStatus: String, Sendable {
    case ready
    case partial
    case misconfigured

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .partial:
            return "Partial"
        case .misconfigured:
            return "Misconfigured"
        }
    }
}

nonisolated struct ConnectionReadiness: Sendable {
    let apnsTokenReady: Bool
    let gatewayConfigured: Bool
    let gatewayReachable: Bool
    let apnsTopicMatchesBundle: Bool?
    let relayConfigured: Bool
    let overallStatus: ConnectionReadinessStatus
    let blockingErrorCode: String?
    let notes: [String]

    static let baseline = ConnectionReadiness(
        apnsTokenReady: false,
        gatewayConfigured: false,
        gatewayReachable: false,
        apnsTopicMatchesBundle: nil,
        relayConfigured: false,
        overallStatus: .misconfigured,
        blockingErrorCode: nil,
        notes: []
    )
}
