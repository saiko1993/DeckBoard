import Foundation
import UIKit

// MARK: - AppConfiguration

enum AppConfiguration {
    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: - UserDefaults Keys

    enum Keys {
        static let deviceRole     = "com.deskboard.deviceRole"
        static let deviceName     = "com.deskboard.deviceName"
        static let appTheme       = "com.deskboard.appTheme"
        static let onboardingDone = "com.deskboard.onboardingDone"
        static let hapticEnabled  = "com.deskboard.hapticEnabled"
        static let silentReceiver = "com.deskboard.silentReceiver"
        static let autoReconnect = "com.deskboard.autoReconnect"
        static let defaultColumns = "com.deskboard.defaultColumns"
        static let pushToken = "com.deskboard.pushToken"
        static let pushWakeEnabled = "com.deskboard.pushWakeEnabled"
        static let pushGatewayURL = "com.deskboard.pushGatewayURL"
        static let pushGatewayAPIKey = "com.deskboard.pushGatewayAPIKey"
    }

    // MARK: - Defaults

    @MainActor
    static var deviceName: String {
        get { UserDefaults.standard.string(forKey: Keys.deviceName) ?? UIDeviceName.current }
        set { UserDefaults.standard.set(newValue, forKey: Keys.deviceName) }
    }

    static var deviceRole: DeviceRole {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.deviceRole) ?? DeviceRole.unset.rawValue
            return DeviceRole(rawValue: raw) ?? .unset
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.deviceRole) }
    }

    static var isOnboardingDone: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.onboardingDone) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.onboardingDone) }
    }

    static var hapticEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.hapticEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hapticEnabled) }
    }

    static var silentReceiver: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.silentReceiver) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.silentReceiver) }
    }

    static var autoReconnect: Bool {
        get { UserDefaults.standard.object(forKey: Keys.autoReconnect) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoReconnect) }
    }

    static var defaultColumns: Int {
        get { UserDefaults.standard.object(forKey: Keys.defaultColumns) as? Int ?? 3 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultColumns) }
    }

    static var pushToken: String? {
        get { UserDefaults.standard.string(forKey: Keys.pushToken) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.pushToken) }
    }

    static var pushWakeEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.pushWakeEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.pushWakeEnabled) }
    }

    static var pushGatewayURL: String {
        get { UserDefaults.standard.string(forKey: Keys.pushGatewayURL) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.pushGatewayURL) }
    }

    static var pushGatewayAPIKey: String? {
        get { UserDefaults.standard.string(forKey: Keys.pushGatewayAPIKey) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.pushGatewayAPIKey) }
    }

    static var pushGatewayBaseURL: URL? {
        let trimmed = pushGatewayURL.trimmed
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

// MARK: - UIDeviceName Helper

@MainActor
private enum UIDeviceName {
    static var current: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "DeskBoard Device"
        #endif
    }
}
