import Foundation

// MARK: - DashboardStore

/// Persists dashboards to UserDefaults as JSON.
final class DashboardStore: @unchecked Sendable {

    static let shared = DashboardStore()

    private let key = "com.deskboard.dashboards"

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

    // MARK: - Load

    func load() -> [Dashboard] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return SampleData.allDashboards
        }
        do {
            return try decoder.decode([Dashboard].self, from: data)
        } catch {
            print("❌ DashboardStore load error: \(error)")
            return SampleData.allDashboards
        }
    }

    // MARK: - Save

    func save(_ dashboards: [Dashboard]) {
        do {
            let data = try encoder.encode(dashboards)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("❌ DashboardStore save error: \(error)")
        }
    }

    // MARK: - Export / Import

    func export(_ dashboard: Dashboard) -> Data? {
        try? encoder.encode(dashboard)
    }

    func `import`(from data: Data) throws -> Dashboard {
        try decoder.decode(Dashboard.self, from: data)
    }

    // MARK: - Reset

    func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}