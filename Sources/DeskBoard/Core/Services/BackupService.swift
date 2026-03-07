import Foundation

nonisolated final class BackupService: @unchecked Sendable {

    static let shared = BackupService()

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    private init() {}

    func exportAll(
        dashboards: [Dashboard],
        deviceName: String,
        settings: BackupSettings? = nil
    ) throws -> Data {
        let backup = DeckBoardBackup(
            dashboards: dashboards,
            deviceName: deviceName,
            settings: settings
        )
        return try encoder.encode(backup)
    }

    func exportSingle(dashboard: Dashboard, deviceName: String) throws -> Data {
        try exportAll(dashboards: [dashboard], deviceName: deviceName)
    }

    func importBackup(from data: Data) throws -> DeckBoardBackup {
        let backup: DeckBoardBackup
        do {
            backup = try decoder.decode(DeckBoardBackup.self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }

        guard backup.version <= DeckBoardBackup.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        guard !backup.dashboards.isEmpty else {
            throw BackupError.emptyBackup
        }

        return backup
    }

    func generateFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = formatter.string(from: Date())
        return "DeskBoard_Backup_\(dateString).json"
    }
}
