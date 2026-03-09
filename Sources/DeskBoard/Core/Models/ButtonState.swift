import Foundation

nonisolated enum ButtonExecutionState: Sendable {
    case idle
    case running
    case queued(position: Int?)
    case success
    case failed(String)
    case cooldown(until: Date)

    var isExecuting: Bool {
        switch self {
        case .running, .queued:
            return true
        default:
            return false
        }
    }

    var badgeText: String? {
        switch self {
        case .running:
            return "RUN"
        case .queued(let position):
            if let position {
                return "Q\(max(position, 1))"
            }
            return "QUEUED"
        case .success:
            return "OK"
        case .failed:
            return "ERR"
        case .cooldown:
            return "CD"
        case .idle:
            return nil
        }
    }
}

nonisolated struct ButtonConfig: Codable, Hashable, Sendable {
    var confirmBeforeExecute: Bool = false
    var cooldownSeconds: Double = 0
    var longPressAction: ButtonAction?
    var showStatusIndicator: Bool = true
    var cornerRadius: Double = 14
    var iconScale: Double = 1.0
    var subtitle: String?
}
