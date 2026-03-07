import Foundation

// MARK: - DeviceRole

enum DeviceRole: String, Codable, CaseIterable, Sendable {
    case sender   = "sender"
    case receiver = "receiver"
    case unset    = "unset"

    var title: String {
        switch self {
        case .sender:   return "Sender"
        case .receiver: return "Receiver"
        case .unset:    return "Choose Role"
        }
    }

    var description: String {
        switch self {
        case .sender:
            return "This device acts as the control panel, sending commands to a receiver."
        case .receiver:
            return "This device listens for and executes commands from a paired sender."
        case .unset:
            return "Select how you want to use this device."
        }
    }

    var systemImage: String {
        switch self {
        case .sender:   return "rectangle.grid.2x2.fill"
        case .receiver: return "antenna.radiowaves.left.and.right"
        case .unset:    return "questionmark.circle"
        }
    }
}

// MARK: - PairedDevice

struct PairedDevice: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var role: DeviceRole
    var pairedAt: Date
    var lastSeenAt: Date?
    var isTrusted: Bool
    var pairingToken: String?

    init(
        id: String,
        displayName: String,
        role: DeviceRole,
        pairedAt: Date = Date(),
        lastSeenAt: Date? = nil,
        isTrusted: Bool = true,
        pairingToken: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.pairedAt = pairedAt
        self.lastSeenAt = lastSeenAt
        self.isTrusted = isTrusted
        self.pairingToken = pairingToken
    }
}

// MARK: - ConnectionState

enum ConnectionState: Equatable, Sendable {
    case idle
    case searching
    case found(peerName: String)
    case pairing
    case connected(to: PairedDevice)
    case disconnected
    case error(message: String)

    var displayTitle: String {
        switch self {
        case .idle:                  return "Idle"
        case .searching:             return "Searching…"
        case .found(let name):       return "Found \(name)"
        case .pairing:               return "Pairing…"
        case .connected(let device): return "Connected to \(device.displayName)"
        case .disconnected:          return "Disconnected"
        case .error(let msg):        return msg
        }
    }

    var systemImage: String {
        switch self {
        case .idle:          return "wifi.slash"
        case .searching:     return "wifi"
        case .found:         return "wifi.exclamationmark"
        case .pairing:       return "lock.open.fill"
        case .connected:     return "checkmark.seal.fill"
        case .disconnected:  return "wifi.slash"
        case .error:         return "exclamationmark.triangle.fill"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isSearching: Bool {
        if case .searching = self { return true }
        return false
    }
}