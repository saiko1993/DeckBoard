import Foundation

nonisolated struct DeckBoardBackup: Codable, Sendable {
    let version: Int
    let exportedAt: Date
    let deviceName: String
    let dashboards: [Dashboard]
    let settings: BackupSettings?

    static let currentVersion = 1

    init(
        dashboards: [Dashboard],
        deviceName: String,
        settings: BackupSettings? = nil
    ) {
        self.version = Self.currentVersion
        self.exportedAt = Date()
        self.deviceName = deviceName
        self.dashboards = dashboards
        self.settings = settings
    }
}

nonisolated struct BackupSettings: Codable, Sendable {
    var hapticEnabled: Bool
    var silentReceiver: Bool
    var defaultColumns: Int
    var autoReconnect: Bool
    var timeoutSeconds: Double
    var retryCount: Int
}

nonisolated enum BackupError: Error, LocalizedError, Sendable {
    case invalidFormat
    case unsupportedVersion(Int)
    case corruptedData
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid backup file format"
        case .unsupportedVersion(let v): return "Unsupported backup version: \(v)"
        case .corruptedData: return "Backup data is corrupted"
        case .emptyBackup: return "Backup contains no data"
        }
    }
}
