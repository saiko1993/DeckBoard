import Foundation

struct ExecutionLog: Codable, Identifiable, Sendable {
    let id: UUID
    let buttonID: UUID?
    let buttonTitle: String
    let action: ButtonAction
    let result: ExecutionResult
    let timestamp: Date
    let duration: TimeInterval
    let targetDevice: String?

    init(
        id: UUID = UUID(),
        buttonID: UUID? = nil,
        buttonTitle: String,
        action: ButtonAction,
        result: ExecutionResult,
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        targetDevice: String? = nil
    ) {
        self.id = id
        self.buttonID = buttonID
        self.buttonTitle = buttonTitle
        self.action = action
        self.result = result
        self.timestamp = timestamp
        self.duration = duration
        self.targetDevice = targetDevice
    }
}

enum ExecutionResult: Codable, Sendable, Hashable {
    case success(detail: String?)
    case failure(error: String)
    case timeout
    case cancelled
    case pending

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .success(let detail): return detail ?? "Success"
        case .failure(let error): return error
        case .timeout: return "Timed out"
        case .cancelled: return "Cancelled"
        case .pending: return "Running…"
        }
    }

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .timeout: return "clock.badge.exclamationmark"
        case .cancelled: return "stop.circle.fill"
        case .pending: return "arrow.triangle.2.circlepath"
        }
    }
}
