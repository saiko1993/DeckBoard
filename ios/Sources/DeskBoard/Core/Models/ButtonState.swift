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
    var targetPolicy: ActionTargetPolicy = .preferReceiver
    var backgroundFallback: BackgroundFallbackPolicy = .relay
    var retryCount: Int = 1
    var timeoutSeconds: Double = 12

    init(
        confirmBeforeExecute: Bool = false,
        cooldownSeconds: Double = 0,
        longPressAction: ButtonAction? = nil,
        showStatusIndicator: Bool = true,
        cornerRadius: Double = 14,
        iconScale: Double = 1.0,
        subtitle: String? = nil,
        targetPolicy: ActionTargetPolicy = .preferReceiver,
        backgroundFallback: BackgroundFallbackPolicy = .relay,
        retryCount: Int = 1,
        timeoutSeconds: Double = 12
    ) {
        self.confirmBeforeExecute = confirmBeforeExecute
        self.cooldownSeconds = cooldownSeconds
        self.longPressAction = longPressAction
        self.showStatusIndicator = showStatusIndicator
        self.cornerRadius = cornerRadius
        self.iconScale = iconScale
        self.subtitle = subtitle
        self.targetPolicy = targetPolicy
        self.backgroundFallback = backgroundFallback
        self.retryCount = max(0, retryCount)
        self.timeoutSeconds = max(3, timeoutSeconds)
    }

    private enum CodingKeys: String, CodingKey {
        case confirmBeforeExecute
        case cooldownSeconds
        case longPressAction
        case showStatusIndicator
        case cornerRadius
        case iconScale
        case subtitle
        case targetPolicy
        case backgroundFallback
        case retryCount
        case timeoutSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmBeforeExecute = try container.decodeIfPresent(Bool.self, forKey: .confirmBeforeExecute) ?? false
        cooldownSeconds = try container.decodeIfPresent(Double.self, forKey: .cooldownSeconds) ?? 0
        longPressAction = try container.decodeIfPresent(ButtonAction.self, forKey: .longPressAction)
        showStatusIndicator = try container.decodeIfPresent(Bool.self, forKey: .showStatusIndicator) ?? true
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 14
        iconScale = try container.decodeIfPresent(Double.self, forKey: .iconScale) ?? 1.0
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        targetPolicy = try container.decodeIfPresent(ActionTargetPolicy.self, forKey: .targetPolicy) ?? .preferReceiver
        backgroundFallback = try container.decodeIfPresent(BackgroundFallbackPolicy.self, forKey: .backgroundFallback) ?? .relay
        retryCount = max(0, try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 1)
        timeoutSeconds = max(3, try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 12)
    }
}
