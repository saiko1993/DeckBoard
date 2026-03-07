import Foundation
import Combine
import SwiftUI
import UIKit

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

    init(
        peerSession: PeerSession = .shared,
        dashboardStore: DashboardStore = .shared,
        trustedDeviceStore: TrustedDeviceStore = .shared
    ) {
        self.peerSession = peerSession
        self.dashboardStore = dashboardStore
        self.trustedDeviceStore = trustedDeviceStore
        loadInitialData()
        bindPeerSession()
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
        if !hasConfigured {
            configurePeerSession()
        } else if !connectionState.isConnected {
            reconnect()
        }
    }

    func handleBecameActive() {
        guard deviceRole != .unset, isOnboardingDone else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        peerSession.enableAutoReconnect()
        peerSession.enterForeground()
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
        configurePeerSession()
    }

    private func configurePeerSession() {
        hasConfigured = true
        peerSession.configure(deviceName: deviceName, role: deviceRole)
        peerSession.startAllServices()
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

    private func executeAction(_ action: ButtonAction) {
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
        case .toggleDarkMode:
            Task { _ = await media.toggleDarkMode() }
        case .screenshot:
            Task { _ = await media.takeScreenshot() }
        case .toggleDoNotDisturb:
            Task { _ = await media.toggleDoNotDisturb() }
        case .presentationNext:
            Task { _ = await media.runShortcut(name: "Next Slide") }
        case .presentationPrevious:
            Task { _ = await media.runShortcut(name: "Previous Slide") }
        case .presentationStart:
            Task { _ = await media.runShortcut(name: "Start Presentation") }
        case .presentationEnd:
            Task { _ = await media.runShortcut(name: "End Presentation") }
        case .lockScreen, .openTerminal, .runScript, .screenRecord,
             .forceQuitApp, .emptyTrash, .sleepDisplay,
             .keyboardShortcut, .macro, .none:
            break
        }
    }

    func acceptPairing() {
        guard let request = incomingPairingRequest else { return }
        peerSession.acceptPairing()
        let device = PairedDevice(
            id: request.peerID.displayName,
            displayName: request.deviceName,
            role: DeviceRole(rawValue: request.deviceRole) ?? .sender,
            pairingToken: PeerSession.pairingToken
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
        peerSession.enableAutoReconnect()
        configurePeerSession()
    }

    func disconnect() {
        peerSession.disconnect()
    }
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
