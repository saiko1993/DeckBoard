import Foundation
import Combine
import SwiftUI
import UIKit

// MARK: - AppState

/// Global application state shared across the entire app via EnvironmentObject.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Role & Onboarding

    @Published var deviceRole: DeviceRole = AppConfiguration.deviceRole
    @Published var isOnboardingDone: Bool = AppConfiguration.isOnboardingDone

    // MARK: - Device Name

    @Published var deviceName: String = AppConfiguration.deviceName {
        didSet { AppConfiguration.deviceName = deviceName }
    }

    // MARK: - Dashboards

    @Published var dashboards: [Dashboard] = []
    @Published var activeDashboardID: UUID?

    // MARK: - Connection (mirrored from PeerSession)

    @Published var connectionState: ConnectionState = .idle
    @Published var discoveredPeers: [DiscoveredPeer] = []
    @Published var incomingPairingRequest: IncomingPairingRequest?
    @Published var lastReceivedCommand: CommandMessage?

    // MARK: - Trusted Devices

    @Published var trustedDevices: [PairedDevice] = []

    // MARK: - Preferences

    @Published var appTheme: AppTheme = .system
    @Published var hapticEnabled: Bool = AppConfiguration.hapticEnabled {
        didSet { AppConfiguration.hapticEnabled = hapticEnabled }
    }
    @Published var silentReceiver: Bool = AppConfiguration.silentReceiver {
        didSet { AppConfiguration.silentReceiver = silentReceiver }
    }

    // MARK: - Private

    private let peerSession: PeerSession
    private let dashboardStore: DashboardStore
    private let trustedDeviceStore: TrustedDeviceStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

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

    // MARK: - Setup

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

    // MARK: - Role Management

    func setRole(_ role: DeviceRole) {
        deviceRole = role
        AppConfiguration.deviceRole = role
        isOnboardingDone = true
        AppConfiguration.isOnboardingDone = true
        configurePeerSession()
    }

    private func configurePeerSession() {
        peerSession.stopAll()
        peerSession.configure(deviceName: deviceName, role: deviceRole)
        switch deviceRole {
        case .sender:
            peerSession.startBrowsing()
        case .receiver:
            peerSession.startAdvertising()
        case .unset:
            break
        }
    }

    // MARK: - Dashboard Management

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

    // MARK: - Sending Commands

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

    // MARK: - Receiving Commands

    private func handleReceivedCommand(_ command: CommandMessage) {
        lastReceivedCommand = command
        if !silentReceiver, hapticEnabled {
            HapticManager.shared.light()
        }
        guard case .buttonAction(let action) = command.payload else { return }
        executeAction(action)
    }

    private func executeAction(_ action: ButtonAction) {
        switch action {
        case .openURL(let url), .openDeepLink(let url):
            guard let url = URL(string: url) else { return }
            UIApplication.shared.open(url)
        case .sendText:
            // Text is shown in the IncomingCommandView for the user to copy/paste
            break
        case .mediaPlay, .mediaPause, .mediaPlayPause,
             .mediaNext, .mediaPrevious,
             .mediaVolumeUp, .mediaVolumeDown:
            // Media control via the receiver's system is limited on iOS.
            // The command is surfaced in the UI for confirmation.
            break
        case .presentationNext, .presentationPrevious,
             .presentationStart, .presentationEnd:
            break
        case .keyboardShortcut, .macro, .none:
            break
        }
    }

    // MARK: - Pairing

    func acceptPairing() {
        guard let request = incomingPairingRequest else { return }
        peerSession.acceptPairing()
        let device = PairedDevice(
            id: request.peerID.displayName,
            displayName: request.deviceName,
            role: DeviceRole(rawValue: request.deviceRole) ?? .sender
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

    // MARK: - Reconnect

    func reconnect() {
        configurePeerSession()
    }

    func disconnect() {
        peerSession.disconnect()
    }
}

// MARK: - AppTheme

enum AppTheme: String, CaseIterable, Sendable {
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