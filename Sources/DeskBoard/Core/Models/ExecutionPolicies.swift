import Foundation

nonisolated enum CommandDeliveryPolicy: String, Codable, Sendable, CaseIterable {
    case bestEffort = "best_effort"
    case atLeastOnce = "at_least_once"
}

nonisolated enum ActionTargetPolicy: String, Codable, Sendable, CaseIterable {
    case preferReceiver = "prefer_receiver"
    case preferMac = "prefer_mac"
    case askEachTime = "ask_each_time"
    case lastActiveCapable = "last_active_capable"

    var title: String {
        switch self {
        case .preferReceiver:
            return "Prefer Receiver"
        case .preferMac:
            return "Prefer Mac"
        case .askEachTime:
            return "Ask Every Time"
        case .lastActiveCapable:
            return "Last Active Capable"
        }
    }
}

nonisolated enum BackgroundFallbackPolicy: String, Codable, Sendable, CaseIterable {
    case relay = "relay"
    case queue = "queue"
    case fail = "fail"

    var title: String {
        switch self {
        case .relay:
            return "Relay to Mac"
        case .queue:
            return "Queue Until Foreground"
        case .fail:
            return "Fail Immediately"
        }
    }
}

nonisolated enum CommandExecutor: String, Codable, Sendable {
    case iosReceiver = "ios_receiver"
    case macRelay = "mac_relay"
    case macAgent = "mac_agent"
    case network = "network"
}
