import Foundation
import KeychainAccess

// MARK: - TrustedDeviceStore

/// Persists trusted paired devices to the Keychain.
final class TrustedDeviceStore: @unchecked Sendable {

    static let shared = TrustedDeviceStore()

    private let keychain = Keychain(service: "com.deskboard.trusteddevices")
    private let key = "trusted_devices"

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

    func loadAll() -> [PairedDevice] {
        guard let data = try? keychain.getData(key) else { return [] }
        return (try? decoder.decode([PairedDevice].self, from: data)) ?? []
    }

    // MARK: - Save

    func save(_ devices: [PairedDevice]) {
        guard let data = try? encoder.encode(devices) else { return }
        try? keychain.set(data, key: key)
    }

    // MARK: - Add / Remove

    func add(_ device: PairedDevice) {
        var devices = loadAll()
        devices.removeAll { $0.id == device.id }
        devices.append(device)
        save(devices)
    }

    func remove(id: String) {
        var devices = loadAll()
        devices.removeAll { $0.id == id }
        save(devices)
    }

    func revoke(id: String) {
        remove(id: id)
    }

    // MARK: - Lookup

    func isTrusted(id: String) -> Bool {
        loadAll().contains { $0.id == id && $0.isTrusted }
    }

    func isTrusted(primaryID: String?, fallbackID: String?) -> Bool {
        let devices = loadAll()
        return devices.contains { device in
            guard device.isTrusted else { return false }
            if let primaryID, device.id == primaryID { return true }
            if let fallbackID, device.id == fallbackID { return true }
            return false
        }
    }

    func updateLastSeen(id: String) {
        var devices = loadAll()
        if let idx = devices.firstIndex(where: { $0.id == id }) {
            devices[idx].lastSeenAt = Date()
            save(devices)
        }
    }

    func updateLastSeen(primaryID: String?, fallbackID: String?) {
        var devices = loadAll()
        if let primaryID, let idx = devices.firstIndex(where: { $0.id == primaryID }) {
            devices[idx].lastSeenAt = Date()
            save(devices)
            return
        }
        if let fallbackID, let idx = devices.firstIndex(where: { $0.id == fallbackID }) {
            devices[idx].lastSeenAt = Date()
            save(devices)
        }
    }

    func validateToken(id: String, token: String) -> Bool {
        let devices = loadAll()
        guard let device = devices.first(where: { $0.id == id && $0.isTrusted }) else {
            return true
        }
        guard let storedToken = device.pairingToken else {
            return true
        }
        return storedToken == token
    }

    func validateToken(primaryID: String?, fallbackID: String?, token: String) -> Bool {
        let devices = loadAll()
        let device = devices.first { current in
            guard current.isTrusted else { return false }
            if let primaryID, current.id == primaryID { return true }
            if let fallbackID, current.id == fallbackID { return true }
            return false
        }

        guard let device else { return true }
        guard let storedToken = device.pairingToken else { return true }
        return storedToken == token
    }

    func addWithToken(_ device: PairedDevice, token: String) {
        var updated = device
        updated.pairingToken = token
        add(updated)
    }

    // MARK: - Clear

    func clearAll() {
        try? keychain.remove(key)
    }
}
