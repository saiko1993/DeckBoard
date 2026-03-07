import Foundation

nonisolated final class ExecutionLogStore: @unchecked Sendable {

    static let shared = ExecutionLogStore()

    private let key = "com.deskboard.executionLogs"
    private let maxStoredLogs = 500

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    private init() {}

    func load() -> [ExecutionLog] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? decoder.decode([ExecutionLog].self, from: data)) ?? []
    }

    func save(_ logs: [ExecutionLog]) {
        let trimmed = Array(logs.prefix(maxStoredLogs))
        guard let data = try? encoder.encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func append(_ log: ExecutionLog) {
        var logs = load()
        logs.insert(log, at: 0)
        save(logs)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func exportLogs() -> Data? {
        let logs = load()
        return try? encoder.encode(logs)
    }
}
