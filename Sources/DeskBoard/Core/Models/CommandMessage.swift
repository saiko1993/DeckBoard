import Foundation

// MARK: - CommandMessage

nonisolated struct CommandMessage: Codable, Identifiable, Sendable {
    let id: UUID
    let type: CommandType
    let payload: CommandPayload
    let senderID: String
    let timestamp: Date

    init(type: CommandType, payload: CommandPayload, senderID: String) {
        self.id = UUID()
        self.type = type
        self.payload = payload
        self.senderID = senderID
        self.timestamp = Date()
    }
}

// MARK: - CommandType

nonisolated enum CommandType: String, Codable, Sendable {
    case action          = "action"
    case actionResult    = "action_result"
    case pairingRequest  = "pairing_request"
    case pairingApproval = "pairing_approval"
    case pairingRejection = "pairing_rejection"
    case heartbeat       = "heartbeat"
    case disconnect      = "disconnect"
    case deviceInfo      = "device_info"
}

// MARK: - CommandPayload

nonisolated enum CommandPayload: Codable, Sendable {
    case buttonAction(ButtonAction)
    case actionResult(ActionExecutionReport)
    case pairingRequest(pairingCode: String, deviceName: String, deviceRole: String)
    case pairingApproval(deviceName: String)
    case pairingRejection(reason: String)
    case heartbeat
    case disconnect
    case deviceInfo(name: String, role: String, version: String)
    case empty

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case type, data
    }

    private enum PayloadType: String, Codable {
        case buttonAction, actionResult, pairingRequest, pairingApproval, pairingRejection
        case heartbeat, disconnect, deviceInfo, empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .buttonAction(let action):
            try container.encode(PayloadType.buttonAction, forKey: .type)
            try container.encode(action, forKey: .data)
        case .actionResult(let report):
            try container.encode(PayloadType.actionResult, forKey: .type)
            try container.encode(report, forKey: .data)
        case .pairingRequest(let code, let name, let role):
            try container.encode(PayloadType.pairingRequest, forKey: .type)
            let data = PairingRequestData(pairingCode: code, deviceName: name, deviceRole: role)
            try container.encode(data, forKey: .data)
        case .pairingApproval(let name):
            try container.encode(PayloadType.pairingApproval, forKey: .type)
            try container.encode(name, forKey: .data)
        case .pairingRejection(let reason):
            try container.encode(PayloadType.pairingRejection, forKey: .type)
            try container.encode(reason, forKey: .data)
        case .heartbeat:
            try container.encode(PayloadType.heartbeat, forKey: .type)
        case .disconnect:
            try container.encode(PayloadType.disconnect, forKey: .type)
        case .deviceInfo(let name, let role, let version):
            try container.encode(PayloadType.deviceInfo, forKey: .type)
            let data = DeviceInfoData(name: name, role: role, version: version)
            try container.encode(data, forKey: .data)
        case .empty:
            try container.encode(PayloadType.empty, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PayloadType.self, forKey: .type)
        switch type {
        case .buttonAction:
            let action = try container.decode(ButtonAction.self, forKey: .data)
            self = .buttonAction(action)
        case .actionResult:
            let report = try container.decode(ActionExecutionReport.self, forKey: .data)
            self = .actionResult(report)
        case .pairingRequest:
            let data = try container.decode(PairingRequestData.self, forKey: .data)
            self = .pairingRequest(pairingCode: data.pairingCode, deviceName: data.deviceName, deviceRole: data.deviceRole)
        case .pairingApproval:
            let name = try container.decode(String.self, forKey: .data)
            self = .pairingApproval(deviceName: name)
        case .pairingRejection:
            let reason = try container.decode(String.self, forKey: .data)
            self = .pairingRejection(reason: reason)
        case .heartbeat:
            self = .heartbeat
        case .disconnect:
            self = .disconnect
        case .deviceInfo:
            let data = try container.decode(DeviceInfoData.self, forKey: .data)
            self = .deviceInfo(name: data.name, role: data.role, version: data.version)
        case .empty:
            self = .empty
        }
    }

    private struct PairingRequestData: Codable {
        let pairingCode: String
        let deviceName: String
        let deviceRole: String
    }

    private struct DeviceInfoData: Codable {
        let name: String
        let role: String
        let version: String
    }
}

nonisolated struct ActionExecutionReport: Codable, Hashable, Sendable {
    let commandID: UUID
    let status: RemoteActionStatus
    let detail: String?
    let target: String?
    let queuePosition: Int?
    let processedAt: Date

    init(
        commandID: UUID,
        status: RemoteActionStatus,
        detail: String? = nil,
        target: String? = nil,
        queuePosition: Int? = nil,
        processedAt: Date = Date()
    ) {
        self.commandID = commandID
        self.status = status
        self.detail = detail
        self.target = target
        self.queuePosition = queuePosition
        self.processedAt = processedAt
    }
}

nonisolated enum RemoteActionStatus: String, Codable, Hashable, Sendable {
    case received
    case queued
    case forwarded
    case success
    case failed
    case timeout
    case cancelled

    var isFinal: Bool {
        switch self {
        case .received, .queued:
            return false
        case .forwarded, .success, .failed, .timeout, .cancelled:
            return true
        }
    }
}
