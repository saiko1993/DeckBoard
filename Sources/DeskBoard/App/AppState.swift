import Foundation
import Combine
import SwiftUI
import UIKit
import os.log

@MainActor
final class AppState: ObservableObject {

    @Published var deviceRole: DeviceRole = AppConfiguration.deviceRole
    @Published var isOnboardingDone: Bool = AppConfiguration.isOnboardingDone

    @Published var deviceName: String = AppConfiguration.deviceName {
        didSet { AppConfiguration.deviceName = deviceName }
    }

    @Published var dashboards: [Dashboard] = []
    @Published var activeDashboardID: UUID?

    @Published var connectionState: ConnectionState = .idle
    @Published var discoveredPeers: [DiscoveredPeer] = []
    @Published var incomingPairingRequest: IncomingPairingRequest?
    @Published var lastReceivedCommand: CommandMessage?
    @Published private(set) var deferredCommandCount: Int = 0

    @Published var trustedDevices: [PairedDevice] = []

    @Published var appTheme: AppTheme = .system
    @Published var hapticEnabled: Bool = AppConfiguration.hapticEnabled {
        didSet { AppConfiguration.hapticEnabled = hapticEnabled }
    }
    @Published var silentReceiver: Bool = AppConfiguration.silentReceiver {
        didSet { AppConfiguration.silentReceiver = silentReceiver }
    }

    private let peerSession: PeerSession
    private let dashboardStore: DashboardStore
    private let trustedDeviceStore: TrustedDeviceStore
    private var cancellables = Set<AnyCancellable>()
    private var hasConfigured = false
    private var hasBootstrapped = false
    private var configuredRole: DeviceRole = .unset
    private var configuredDeviceName: String = ""
    private var deferredForegroundActions: [DeferredAction] = []

    init(
        peerSession: PeerSession = .shared,
        dashboardStore: DashboardStore = .shared,
        trustedDeviceStore: TrustedDeviceStore = .shared
    ) {
        self.peerSession = peerSession
        self.dashboardStore = dashboardStore
        self.trustedDeviceStore = trustedDeviceStore
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        loadInitialData()
        bindPeerSession()
        peerSession.setAutoReconnectEnabled(AppConfiguration.autoReconnect)
        syncPushRegistration()
    }

    private func loadInitialData() {
        dashboards = dashboardStore.load()
        activeDashboardID = dashboards.first?.id
        trustedDevices = trustedDeviceStore.loadAll()
    }

    private func bindPeerSession() {
        peerSession.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.connectionState = state }
            .store(in: &cancellables)

        peerSession.$discoveredPeers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peers in self?.discoveredPeers = peers }
            .store(in: &cancellables)

        peerSession.$incomingPairingRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in self?.incomingPairingRequest = request }
            .store(in: &cancellables)

        peerSession.$receivedCommand
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] command in self?.handleReceivedCommand(command) }
            .store(in: &cancellables)
    }

    func ensureConnectionActive() {
        guard deviceRole != .unset, isOnboardingDone else { return }
        peerSession.setAutoReconnectEnabled(AppConfiguration.autoReconnect)

        if needsSessionRebuild {
            configurePeerSession(forceRebuild: true)
            return
        }

        if !connectionState.isConnected {
            peerSession.restartServices()
        }
    }

    func handleBecameActive() {
        guard deviceRole != .unset, isOnboardingDone else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        peerSession.setAutoReconnectEnabled(AppConfiguration.autoReconnect)
        peerSession.enterForeground()
        flushDeferredForegroundActionsIfNeeded()
    }

    func handleEnteredBackground() {
        guard deviceRole != .unset, isOnboardingDone else { return }
        peerSession.enterBackground()
    }

    func setRole(_ role: DeviceRole) {
        deviceRole = role
        AppConfiguration.deviceRole = role
        isOnboardingDone = true
        AppConfiguration.isOnboardingDone = true
        configurePeerSession(forceRebuild: true)
        syncPushRegistration()
    }

    private var needsSessionRebuild: Bool {
        !hasConfigured || configuredRole != deviceRole || configuredDeviceName != deviceName
    }

    private func configurePeerSession(forceRebuild: Bool = false) {
        let shouldRebuild = forceRebuild || needsSessionRebuild
        peerSession.setAutoReconnectEnabled(AppConfiguration.autoReconnect)
        if shouldRebuild {
            hasConfigured = true
            configuredRole = deviceRole
            configuredDeviceName = deviceName
            peerSession.configure(deviceName: deviceName, role: deviceRole)
        }
        peerSession.startAllServices()
        syncPushRegistration()
    }

    func saveDashboards() {
        dashboardStore.save(dashboards)
    }

    func addDashboard(_ dashboard: Dashboard) {
        dashboards.append(dashboard)
        if activeDashboardID == nil { activeDashboardID = dashboard.id }
        saveDashboards()
    }

    func deleteDashboard(id: UUID) {
        dashboards.removeAll { $0.id == id }
        if activeDashboardID == id { activeDashboardID = dashboards.first?.id }
        saveDashboards()
    }

    func updateDashboard(_ dashboard: Dashboard) {
        dashboards.upsert(dashboard)
        saveDashboards()
    }

    var activeDashboard: Dashboard? {
        dashboards.first { $0.id == activeDashboardID }
    }

    func send(action: ButtonAction, button: DeskButton) {
        guard connectionState.isConnected else { return }
        if hapticEnabled && button.hapticFeedback {
            HapticManager.shared.medium()
        }
        let message = CommandMessage(
            type: .action,
            payload: .buttonAction(action),
            senderID: deviceName
        )
        peerSession.send(command: message)
    }

    private func handleReceivedCommand(_ command: CommandMessage) {
        lastReceivedCommand = command
        if !silentReceiver, hapticEnabled {
            HapticManager.shared.light()
        }
        guard case .buttonAction(let action) = command.payload else { return }
        executeAction(action)
    }

    private func executeAction(_ action: ButtonAction, allowDeferral: Bool = true) {
        if allowDeferral,
           action.requiresForegroundOnIOSReceiver,
           UIApplication.shared.applicationState != .active {
            handleForegroundRequiredAction(action)
            return
        }

        performActionImmediately(action)
    }

    private func performActionImmediately(_ action: ButtonAction) {
        let media = MediaControlService.shared
        switch action {
        case .openURL(let url), .openDeepLink(let url):
            guard let url = URL(string: url) else { return }
            UIApplication.shared.open(url)
        case .sendText(let text):
            UIPasteboard.general.string = text
        case .mediaVolumeUp:
            media.volumeUp()
        case .mediaVolumeDown:
            media.volumeDown()
        case .mediaMute:
            media.mute()
        case .mediaPlay:
            media.mediaPlay()
        case .mediaPause:
            media.mediaPause()
        case .mediaPlayPause:
            media.mediaPlayPause()
        case .mediaNext:
            media.mediaNext()
        case .mediaPrevious:
            media.mediaPrevious()
        case .brightnessUp:
            media.brightnessUp()
        case .brightnessDown:
            media.brightnessDown()
        case .openApp(let appID):
            Task { _ = await media.openAppByID(appID) }
        case .runShortcut(let name):
            Task { _ = await media.runShortcut(name: name) }
        case .runScript(let name):
            Task { _ = await media.runScript(name: name) }
        case .toggleDarkMode:
            Task { _ = await media.toggleDarkMode() }
        case .screenshot:
            Task { _ = await media.takeScreenshot() }
        case .screenRecord:
            Task { _ = await media.toggleScreenRecord() }
        case .toggleDoNotDisturb:
            Task { _ = await media.toggleDoNotDisturb() }
        case .sleepDisplay:
            Task { _ = await media.sleepDisplay() }
        case .presentationNext:
            Task { _ = await media.runShortcut(name: "Next Slide") }
        case .presentationPrevious:
            Task { _ = await media.runShortcut(name: "Previous Slide") }
        case .presentationStart:
            Task { _ = await media.runShortcut(name: "Start Presentation") }
        case .presentationEnd:
            Task { _ = await media.runShortcut(name: "End Presentation") }
        case .macro(let actions):
            Task { @MainActor in
                for macroAction in actions {
                    executeAction(macroAction)
                    try? await Task.sleep(for: .milliseconds(80))
                }
            }
        case .lockScreen, .openTerminal, .forceQuitApp,
             .emptyTrash, .keyboardShortcut, .none:
            break
        }
    }

    private func handleForegroundRequiredAction(_ action: ButtonAction) {
        Task {
            let forwarded = await BackgroundCommandRelayService.shared.forward(
                action: action,
                sourceDeviceName: deviceName,
                reason: "receiver_background_foreground_required"
            )
            guard !forwarded else { return }
            await MainActor.run {
                enqueueDeferredForegroundAction(action)
            }
        }
    }

    private func enqueueDeferredForegroundAction(_ action: ButtonAction) {
        if let last = deferredForegroundActions.last,
           last.action == action,
           Date().timeIntervalSince(last.queuedAt) < 0.75 {
            return
        }

        deferredForegroundActions.append(DeferredAction(action: action, queuedAt: Date()))
        if deferredForegroundActions.count > 80 {
            deferredForegroundActions.removeFirst(deferredForegroundActions.count - 80)
        }
        deferredCommandCount = deferredForegroundActions.count
    }

    private func flushDeferredForegroundActionsIfNeeded() {
        guard UIApplication.shared.applicationState == .active else { return }
        guard !deferredForegroundActions.isEmpty else { return }

        let pendingActions = deferredForegroundActions.map(\.action)
        deferredForegroundActions.removeAll()
        deferredCommandCount = 0

        Task { @MainActor in
            for action in pendingActions {
                executeAction(action, allowDeferral: false)
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    func acceptPairing() {
        guard let request = incomingPairingRequest else { return }
        peerSession.acceptPairing()
        let trustedID = request.deviceUUID ?? request.peerID.displayName
        let device = PairedDevice(
            id: trustedID,
            displayName: request.deviceName,
            role: DeviceRole(rawValue: request.deviceRole) ?? .sender,
            pairingToken: request.pairingToken
        )
        trustedDeviceStore.add(device)
        trustedDevices = trustedDeviceStore.loadAll()
    }

    func rejectPairing() {
        peerSession.rejectPairing()
    }

    func revokeDevice(id: String) {
        trustedDeviceStore.revoke(id: id)
        trustedDevices = trustedDeviceStore.loadAll()
    }

    func reconnect() {
        peerSession.setAutoReconnectEnabled(AppConfiguration.autoReconnect)
        if needsSessionRebuild {
            configurePeerSession(forceRebuild: true)
            return
        }
        peerSession.restartServices()
    }

    func setAutoReconnect(_ enabled: Bool) {
        AppConfiguration.autoReconnect = enabled
        peerSession.setAutoReconnectEnabled(enabled)
        if enabled {
            ensureConnectionActive()
        }
    }

    private func syncPushRegistration() {
        let role = deviceRole
        let name = deviceName
        Task {
            await PushWakeService.shared.registerCurrentDevice(role: role, deviceName: name)
        }
    }

    func disconnect() {
        peerSession.disconnect()
    }
}

private nonisolated struct DeferredAction: Sendable {
    let action: ButtonAction
    let queuedAt: Date
}

nonisolated enum AppTheme: String, CaseIterable, Sendable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

actor BackgroundCommandRelayService {
    static let shared = BackgroundCommandRelayService()

    private let session: URLSession
    private let log = Logger(subsystem: "com.deskboard", category: "BackgroundRelay")

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        session = URLSession(configuration: config)
    }

    func forward(action: ButtonAction, sourceDeviceName: String, reason: String) async -> Bool {
        guard AppConfiguration.backgroundRelayEnabled else { return false }
        guard let baseURL = AppConfiguration.backgroundRelayBaseURL else { return false }

        let relayAction = RelayActionPayload(action: action)
        guard relayAction.kind != "none" else { return false }

        let body = RelayCommandRequest(
            sourceDeviceUUID: PeerSession.stableDeviceUUID,
            sourceDeviceName: sourceDeviceName,
            appVersion: AppConfiguration.appVersion,
            reason: reason,
            action: relayAction
        )

        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("v1/execute"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let apiKey = AppConfiguration.backgroundRelayAPIKey?.trimmed, !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "x-deskboard-key")
            }
            request.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            if (200...299).contains(http.statusCode) {
                log.info("RELAY-001 Forwarded action=\(relayAction.kind, privacy: .public)")
                return true
            }
            log.error("RELAY-002 Relay failed status=\(http.statusCode, privacy: .public)")
            return false
        } catch {
            log.error("RELAY-003 Relay request failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}

actor PushWakeService {
    static let shared = PushWakeService()

    private let session: URLSession
    private let log = Logger(subsystem: "com.deskboard", category: "PushWakeService")

    private var lastRegistrationSignature: String?
    private var lastWakeAtByTarget: [String: Date] = [:]
    private let registrationDebounce: TimeInterval = 30
    private let wakeThrottle: TimeInterval = 12
    private var lastRegistrationAt: Date?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        session = URLSession(configuration: config)
    }

    func registerCurrentDevice(role: DeviceRole, deviceName: String) async {
        guard AppConfiguration.pushWakeEnabled else { return }
        guard role != .unset else { return }
        guard let baseURL = AppConfiguration.pushGatewayBaseURL else { return }
        guard let apnsToken = AppConfiguration.pushToken?.trimmed, !apnsToken.isEmpty else { return }

        let payload = RegisterPayload(
            deviceUUID: PeerSession.stableDeviceUUID,
            pairingToken: PeerSession.pairingToken,
            apnsToken: apnsToken,
            role: role.rawValue,
            deviceName: deviceName.trimmed,
            appVersion: AppConfiguration.appVersion
        )

        let signature = [
            payload.deviceUUID,
            payload.apnsToken,
            payload.role,
            payload.deviceName,
            payload.appVersion
        ].joined(separator: "|")

        if signature == lastRegistrationSignature,
           let lastRegistrationAt,
           Date().timeIntervalSince(lastRegistrationAt) < registrationDebounce {
            return
        }

        do {
            let url = baseURL.appendingPathComponent("v1/register")
            let response = try await postJSON(url: url, body: payload)
            if (200...299).contains(response.statusCode) {
                lastRegistrationSignature = signature
                lastRegistrationAt = Date()
                log.info("PUSHWAKE-001 Device registration succeeded")
                return
            }
            log.error("PUSHWAKE-002 Registration failed status=\(response.statusCode, privacy: .public)")
        } catch {
            log.error("PUSHWAKE-003 Registration request failed: \(String(describing: error), privacy: .public)")
        }
    }

    func wakePeer(targetDeviceUUID: String, reason: String) async {
        guard AppConfiguration.pushWakeEnabled else { return }
        guard let baseURL = AppConfiguration.pushGatewayBaseURL else { return }
        guard !targetDeviceUUID.trimmed.isEmpty else { return }

        let key = targetDeviceUUID.trimmed
        if let last = lastWakeAtByTarget[key], Date().timeIntervalSince(last) < wakeThrottle {
            return
        }
        lastWakeAtByTarget[key] = Date()

        let payload = WakePayload(
            fromDeviceUUID: PeerSession.stableDeviceUUID,
            fromPairingToken: PeerSession.pairingToken,
            targetDeviceUUID: key,
            reason: reason
        )

        do {
            let url = baseURL.appendingPathComponent("v1/wake")
            let response = try await postJSON(url: url, body: payload)
            if (200...299).contains(response.statusCode) {
                log.info("PUSHWAKE-004 Wake request succeeded for target=\(key, privacy: .public)")
                return
            }
            log.error("PUSHWAKE-005 Wake request failed status=\(response.statusCode, privacy: .public)")
        } catch {
            log.error("PUSHWAKE-006 Wake request failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func postJSON<T: Encodable>(url: URL, body: T) async throws -> HTTPURLResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = AppConfiguration.pushGatewayAPIKey?.trimmed, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-deskboard-key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return httpResponse
    }
}

private nonisolated struct RegisterPayload: Codable, Sendable {
    let deviceUUID: String
    let pairingToken: String
    let apnsToken: String
    let role: String
    let deviceName: String
    let appVersion: String
}

private nonisolated struct WakePayload: Codable, Sendable {
    let fromDeviceUUID: String
    let fromPairingToken: String
    let targetDeviceUUID: String
    let reason: String
}

private nonisolated struct RelayCommandRequest: Codable, Sendable {
    let sourceDeviceUUID: String
    let sourceDeviceName: String
    let appVersion: String
    let reason: String
    let action: RelayActionPayload
}

private nonisolated struct RelayActionPayload: Codable, Sendable {
    let kind: String
    let value: String?
    let appID: String?
    let modifiers: [String]?
    let key: String?
    let actions: [RelayActionPayload]?

    private init(
        kind: String,
        value: String?,
        appID: String?,
        modifiers: [String]?,
        key: String?,
        actions: [RelayActionPayload]?
    ) {
        self.kind = kind
        self.value = value
        self.appID = appID
        self.modifiers = modifiers
        self.key = key
        self.actions = actions
    }

    init(action: ButtonAction) {
        switch action {
        case .none:
            self = .init(kind: "none", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .openURL(let url):
            self = .init(kind: "open_url", value: url, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .openDeepLink(let url):
            self = .init(kind: "open_deep_link", value: url, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .sendText(let text):
            self = .init(kind: "send_text", value: text, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaPlay:
            self = .init(kind: "media_play", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaPause:
            self = .init(kind: "media_pause", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaPlayPause:
            self = .init(kind: "media_play_pause", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaNext:
            self = .init(kind: "media_next", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaPrevious:
            self = .init(kind: "media_previous", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaVolumeUp:
            self = .init(kind: "media_volume_up", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaVolumeDown:
            self = .init(kind: "media_volume_down", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .mediaMute:
            self = .init(kind: "media_mute", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .presentationNext:
            self = .init(kind: "presentation_next", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .presentationPrevious:
            self = .init(kind: "presentation_previous", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .presentationStart:
            self = .init(kind: "presentation_start", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .presentationEnd:
            self = .init(kind: "presentation_end", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .keyboardShortcut(let modifiers, let key):
            self = .init(kind: "keyboard_shortcut", value: nil, appID: nil, modifiers: modifiers, key: key, actions: nil)

        case .openApp(let appID):
            self = .init(kind: "open_app", value: nil, appID: appID, modifiers: nil, key: nil, actions: nil)

        case .brightnessUp:
            self = .init(kind: "brightness_up", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .brightnessDown:
            self = .init(kind: "brightness_down", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .lockScreen:
            self = .init(kind: "lock_screen", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .runShortcut(let name):
            self = .init(kind: "run_shortcut", value: name, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .openTerminal:
            self = .init(kind: "open_terminal", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .runScript(let name):
            self = .init(kind: "run_script", value: name, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .toggleDarkMode:
            self = .init(kind: "toggle_dark_mode", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .screenshot:
            self = .init(kind: "screenshot", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .screenRecord:
            self = .init(kind: "screen_record", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .forceQuitApp:
            self = .init(kind: "force_quit_app", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .emptyTrash:
            self = .init(kind: "empty_trash", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .toggleDoNotDisturb:
            self = .init(kind: "toggle_dnd", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .sleepDisplay:
            self = .init(kind: "sleep_display", value: nil, appID: nil, modifiers: nil, key: nil, actions: nil)

        case .macro(let actions):
            self = .init(
                kind: "macro",
                value: nil,
                appID: nil,
                modifiers: nil,
                key: nil,
                actions: actions.map { RelayActionPayload(action: $0) }
            )
        }
    }
}
