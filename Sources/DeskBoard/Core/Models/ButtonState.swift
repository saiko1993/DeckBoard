import Foundation

enum ButtonExecutionState: Sendable {
    case idle
    case running
    case success
    case failed(String)
    case cooldown(until: Date)

    var isExecuting: Bool {
        if case .running = self { return true }
        return false
    }
}

struct ButtonConfig: Codable, Hashable, Sendable {
    var confirmBeforeExecute: Bool = false
    var cooldownSeconds: Double = 0
    var longPressAction: ButtonAction?
    var showStatusIndicator: Bool = true
    var cornerRadius: Double = 14
    var iconScale: Double = 1.0
    var subtitle: String?
}
