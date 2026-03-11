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
    @Published private(set) var senderButtonStates: [UUID: ButtonExecutionState] = [:]

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
    private var deferredForegroundActions: [DeferredExecutionAction] = []
    private var pendingQuickIntentActions: [ButtonAction] = []
    private var pendingSentCommands: [UUID: PendingSentCommand] = [:]
    private let stateLog = Logger(subsystem: "com.deskboard", category: "AppState")
    private let executionRouter = ExecutionRouter.shared

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
            .sink { [weak self] state in
                guard let self else { return }
                self.connectionState = state
                if state.isConnected {
                    self.resendPendingCommandsOnReconnect()
                    self.flushPendingQuickIntentActionsIfNeeded()
                }
            }
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
        flushPendingQuickIntentActionsIfNeeded()
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
        let maxAttempts = max(1, button.config.retryCount + 1)
        let timeoutSeconds = max(3, Int(button.config.timeoutSeconds.rounded()))
        let message = CommandMessage(
            type: .action,
            payload: .buttonAction(action),
            senderID: deviceName,
            protocolVersion: 2,
            originDeviceUUID: PeerSession.stableDeviceUUID,
            traceID: UUID().uuidString,
            deliveryPolicy: button.config.retryCount > 0 ? .atLeastOnce : .bestEffort,
            ttlSeconds: timeoutSeconds,
            targetPolicy: button.config.targetPolicy,
            backgroundFallback: button.config.backgroundFallback,
            attempt: 1,
            maxAttempts: maxAttempts
        )
        pendingSentCommands[message.id] = PendingSentCommand(
            commandID: message.id,
            buttonID: button.id,
            buttonTitle: button.title,
            action: action,
            message: message,
            attempt: 1,
            maxAttempts: maxAttempts,
            sentAt: Date(),
            timeoutAt: Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        )
        senderButtonStates[button.id] = .running
        peerSession.send(command: message)
        monitorPendingCommandTimeout(message.id)
    }

    private func handleReceivedCommand(_ command: CommandMessage) {
        lastReceivedCommand = command
        switch command.payload {
        case .buttonAction(let action):
            guard deviceRole == .receiver else { return }
            if !silentReceiver, hapticEnabled {
                HapticManager.shared.light()
            }
            Task { @MainActor in
                await processIncomingAction(command: command, action: action)
            }

        case .actionResult(let report):
            guard deviceRole == .sender else { return }
            handleActionExecutionReport(report)

        default:
            break
        }
    }

    private func processIncomingAction(command: CommandMessage, action: ButtonAction) async {
        let routingContext = ActionRoutingContext(
            commandID: command.id,
            traceID: command.traceID,
            attempt: command.attempt,
            maxAttempts: command.maxAttempts,
            targetPolicy: command.targetPolicy ?? .preferReceiver,
            fallbackPolicy: command.backgroundFallback ?? .relay,
            ttlSeconds: command.ttlSeconds
        )

        sendActionExecutionReport(
            commandID: command.id,
            status: .received,
            detail: "Command received",
            executor: .iosReceiver,
            attempt: command.attempt
        )

        let routed = await executionRouter.route(
            action: action,
            context: routingContext,
            sourceDeviceName: deviceName,
            executeLocal: { [weak self] action in
                guard let self else {
                    return .failure(error: "Receiver unavailable")
                }
                return await self.executeActionAndReturnResult(action)
            },
            enqueueDeferred: { [weak self] deferred in
                guard let self else { return 1 }
                return self.enqueueDeferredForegroundAction(deferred)
            }
        )

        sendActionExecutionReport(
            commandID: command.id,
            status: routed.status,
            detail: routed.detail,
            executor: routed.executor,
            queuePosition: routed.queuePosition,
            errorCode: routed.errorCode,
            attempt: command.attempt,
            latencyMs: routed.latencyMs
        )
    }

    private func executeActionAndReturnResult(_ action: ButtonAction) async -> ExecutionResult {
        let media = MediaControlService.shared
        switch action {
        case .none:
            return .success(detail: "No action")

        case .openURL(let raw), .openDeepLink(let raw):
            guard !raw.trimmed.isEmpty, let url = URL(string: raw) else {
                return .failure(error: "Invalid URL")
            }
            let opened = await UIApplication.shared.open(url)
            return opened ? .success(detail: "Opened URL") : .failure(error: "Could not open URL")

        case .sendText(let text):
            UIPasteboard.general.string = text
            return .success(detail: "Copied to clipboard")

        case .mediaVolumeUp:
            media.volumeUp()
            return .success(detail: "Volume up")

        case .mediaVolumeDown:
            media.volumeDown()
            return .success(detail: "Volume down")

        case .mediaMute:
            media.mute()
            return .success(detail: "Muted")

        case .mediaPlay:
            media.mediaPlay()
            return .success(detail: "Play")

        case .mediaPause:
            media.mediaPause()
            return .success(detail: "Pause")

        case .mediaPlayPause:
            media.mediaPlayPause()
            return .success(detail: "Play/Pause")

        case .mediaNext:
            media.mediaNext()
            return .success(detail: "Next")

        case .mediaPrevious:
            media.mediaPrevious()
            return .success(detail: "Previous")

        case .brightnessUp:
            media.brightnessUp()
            return .success(detail: "Brightness up")

        case .brightnessDown:
            media.brightnessDown()
            return .success(detail: "Brightness down")

        case .openApp(let appID):
            let opened = await media.openAppByID(appID)
            return opened ? .success(detail: "Opened app") : .failure(error: "App not installed")

        case .runShortcut(let name):
            let opened = await media.runShortcut(name: name)
            return opened ? .success(detail: "Running shortcut") : .failure(error: "Could not run shortcut")

        case .runScript(let name):
            let opened = await media.runScript(name: name)
            return opened ? .success(detail: "Running script") : .failure(error: "Could not run script")

        case .toggleDarkMode:
            let toggled = await media.toggleDarkMode()
            return toggled ? .success(detail: "Dark mode toggled") : .failure(error: "Could not toggle")

        case .screenshot:
            let taken = await media.takeScreenshot()
            return taken ? .success(detail: "Screenshot") : .failure(error: "Could not take screenshot")

        case .screenRecord:
            let toggled = await media.toggleScreenRecord()
            return toggled ? .success(detail: "Screen recording toggled") : .failure(error: "Could not toggle")

        case .toggleDoNotDisturb:
            let toggled = await media.toggleDoNotDisturb()
            return toggled ? .success(detail: "Do Not Disturb toggled") : .failure(error: "Could not toggle DND")

        case .sleepDisplay:
            let slept = await media.sleepDisplay()
            return slept ? .success(detail: "Display sleeping") : .failure(error: "Could not sleep display")

        case .openTerminal:
            let opened = await media.openTerminal()
            return opened ? .success(detail: "Opened Terminal") : .failure(error: "Could not open Terminal")

        case .forceQuitApp:
            let quit = await media.forceQuitFrontApp()
            return quit ? .success(detail: "Force quit command sent") : .failure(error: "Could not force quit")

        case .emptyTrash:
            let emptied = await media.emptyTrash()
            return emptied ? .success(detail: "Trash emptied") : .failure(error: "Could not empty trash")

        case .presentationNext:
            let opened = await media.runShortcut(name: "Next Slide")
            return opened ? .success(detail: "Next slide") : .failure(error: "Shortcut failed")

        case .presentationPrevious:
            let opened = await media.runShortcut(name: "Previous Slide")
            return opened ? .success(detail: "Previous slide") : .failure(error: "Shortcut failed")

        case .presentationStart:
            let opened = await media.runShortcut(name: "Start Presentation")
            return opened ? .success(detail: "Start presentation") : .failure(error: "Shortcut failed")

        case .presentationEnd:
            let opened = await media.runShortcut(name: "End Presentation")
            return opened ? .success(detail: "End presentation") : .failure(error: "Shortcut failed")

        case .keyboardShortcut:
            return .failure(error: "Keyboard shortcut is not supported on iOS receiver")

        case .lockScreen:
            return .failure(error: "Lock screen command is not supported on iOS receiver")

        case .macro(let actions):
            for (idx, nested) in actions.enumerated() {
                let nestedResult = await executeActionAndReturnResult(nested)
                if case .failure(let error) = nestedResult {
                    return .failure(error: "Step \(idx + 1) failed: \(error)")
                }
            }
            return .success(detail: "Macro completed")
        }
    }

    private func enqueueDeferredForegroundAction(_ deferred: DeferredExecutionAction) -> Int {
        if deferredForegroundActions.contains(where: { $0.context.commandID == deferred.context.commandID }) {
            return deferredForegroundActions.firstIndex(where: { $0.context.commandID == deferred.context.commandID }).map { $0 + 1 } ?? 1
        }

        deferredForegroundActions.append(deferred)
        if deferredForegroundActions.count > 80 {
            deferredForegroundActions.removeFirst(deferredForegroundActions.count - 80)
        }
        deferredCommandCount = deferredForegroundActions.count
        return deferredForegroundActions.count
    }

    private func flushDeferredForegroundActionsIfNeeded() {
        guard UIApplication.shared.applicationState == .active else { return }
        guard !deferredForegroundActions.isEmpty else { return }

        let pendingActions = deferredForegroundActions
        deferredForegroundActions.removeAll()
        deferredCommandCount = 0

        Task { @MainActor in
            for deferred in pendingActions {
                let routed = await executionRouter.routeDeferred(
                    deferred: deferred,
                    sourceDeviceName: deviceName,
                    executeLocal: { [weak self] action in
                        guard let self else {
                            return .failure(error: "Receiver unavailable")
                        }
                        return await self.executeActionAndReturnResult(action)
                    }
                )

                sendActionExecutionReport(
                    commandID: deferred.context.commandID,
                    status: routed.status,
                    detail: routed.detail,
                    executor: routed.executor,
                    errorCode: routed.errorCode,
                    attempt: deferred.context.attempt,
                    latencyMs: routed.latencyMs
                )
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    private func sendActionExecutionReport(
        commandID: UUID,
        status: RemoteActionStatus,
        detail: String?,
        executor: CommandExecutor,
        queuePosition: Int? = nil,
        errorCode: String? = nil,
        attempt: Int = 1,
        latencyMs: Int? = nil
    ) {
        let report = ActionExecutionReport(
            commandID: commandID,
            status: status,
            detail: detail,
            target: executor.rawValue,
            queuePosition: queuePosition,
            executor: executor,
            errorCode: errorCode,
            attempt: attempt,
            latencyMs: latencyMs
        )
        let message = CommandMessage(
            type: .actionResult,
            payload: .actionResult(report),
            senderID: deviceName,
            protocolVersion: 2,
            originDeviceUUID: PeerSession.stableDeviceUUID,
            traceID: UUID().uuidString,
            deliveryPolicy: .bestEffort,
            ttlSeconds: 30
        )
        peerSession.send(command: message)
    }

    private func handleActionExecutionReport(_ report: ActionExecutionReport) {
        guard var pending = pendingSentCommands[report.commandID] else { return }

        switch report.status {
        case .received:
            senderButtonStates[pending.buttonID] = .running
            pending.timeoutAt = Date().addingTimeInterval(20)
            pendingSentCommands[report.commandID] = pending

        case .queued:
            senderButtonStates[pending.buttonID] = .queued(position: report.queuePosition)
            pending.timeoutAt = Date().addingTimeInterval(300)
            pendingSentCommands[report.commandID] = pending

        case .forwarded, .success:
            senderButtonStates[pending.buttonID] = .success
            pendingSentCommands.removeValue(forKey: report.commandID)
            appendExecutionLog(for: pending, report: report)
            scheduleSenderButtonStateReset(buttonID: pending.buttonID, expected: .success, delayMS: 1400)

        case .failed:
            senderButtonStates[pending.buttonID] = .failed(report.detail ?? "Execution failed")
            pendingSentCommands.removeValue(forKey: report.commandID)
            appendExecutionLog(for: pending, report: report)
            scheduleSenderButtonStateReset(buttonID: pending.buttonID, expected: .failed(""), delayMS: 2200)

        case .timeout:
            senderButtonStates[pending.buttonID] = .failed("Timed out")
            pendingSentCommands.removeValue(forKey: report.commandID)
            appendExecutionLog(for: pending, report: report)
            scheduleSenderButtonStateReset(buttonID: pending.buttonID, expected: .failed(""), delayMS: 2200)

        case .cancelled:
            senderButtonStates[pending.buttonID] = .failed("Cancelled")
            pendingSentCommands.removeValue(forKey: report.commandID)
            appendExecutionLog(for: pending, report: report)
            scheduleSenderButtonStateReset(buttonID: pending.buttonID, expected: .failed(""), delayMS: 1600)
        }
    }

    private func monitorPendingCommandTimeout(_ commandID: UUID) {
        Task { @MainActor in
            while let pending = pendingSentCommands[commandID] {
                let remaining = pending.timeoutAt.timeIntervalSinceNow
                if remaining <= 0 {
                    if pending.attempt < pending.maxAttempts {
                        var updated = pending
                        updated.attempt += 1
                        let timeout = TimeInterval(updated.message.ttlSeconds ?? 12)
                        updated.timeoutAt = Date().addingTimeInterval(max(3, timeout))
                        updated.message = updated.message.withAttempt(updated.attempt)
                        pendingSentCommands[commandID] = updated

                        peerSession.send(command: updated.message)
                        senderButtonStates[pending.buttonID] = .running
                        stateLog.info(
                            "SEND-RETRY-001 Retry commandID=\(commandID.uuidString, privacy: .public) attempt=\(updated.attempt, privacy: .public)"
                        )
                        continue
                    } else {
                        pendingSentCommands.removeValue(forKey: commandID)
                        senderButtonStates[pending.buttonID] = .failed("Timed out")

                        let report = ActionExecutionReport(
                            commandID: commandID,
                            status: .timeout,
                            detail: "No confirmation from receiver",
                            target: CommandExecutor.network.rawValue,
                            executor: .network,
                            errorCode: "timeout_no_ack",
                            attempt: pending.attempt
                        )
                        appendExecutionLog(for: pending, report: report)
                        scheduleSenderButtonStateReset(buttonID: pending.buttonID, expected: .failed(""), delayMS: 2400)
                        stateLog.error("SEND-ACK-001 Command timeout commandID=\(commandID.uuidString, privacy: .public)")
                        return
                    }
                }

                let interval = min(max(remaining, 0.5), 2.0)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func resendPendingCommandsOnReconnect() {
        guard !pendingSentCommands.isEmpty else { return }
        let now = Date()
        for (commandID, pending) in pendingSentCommands {
            if pending.timeoutAt > now {
                peerSession.send(command: pending.message)
                stateLog.info("SEND-OUTBOX-001 Resent commandID=\(commandID.uuidString, privacy: .public) on reconnect")
            }
        }
    }

    private func scheduleSenderButtonStateReset(buttonID: UUID, expected: ButtonExecutionState, delayMS: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMS))
            guard let current = senderButtonStates[buttonID] else { return }
            switch (current, expected) {
            case (.success, .success):
                senderButtonStates[buttonID] = .idle
            case (.failed, .failed):
                senderButtonStates[buttonID] = .idle
            default:
                break
            }
        }
    }

    private func appendExecutionLog(for pending: PendingSentCommand, report: ActionExecutionReport) {
        let elapsed = Date().timeIntervalSince(pending.sentAt)
        let result: ExecutionResult

        switch report.status {
        case .forwarded:
            result = .success(detail: report.detail ?? "Forwarded to Mac relay")
        case .success:
            result = .success(detail: report.detail)
        case .failed:
            result = .failure(error: report.detail ?? "Execution failed")
        case .timeout:
            result = .timeout
        case .cancelled:
            result = .cancelled
        case .queued, .received:
            result = .pending
        }

        let targetName: String? = {
            switch connectionState {
            case .connected(let device):
                return device.displayName
            default:
                return report.target ?? report.executor.rawValue
            }
        }()

        let log = ExecutionLog(
            buttonID: pending.buttonID,
            buttonTitle: pending.buttonTitle,
            action: pending.action,
            result: result,
            duration: elapsed,
            targetDevice: targetName
        )
        ExecutionLogStore.shared.append(log)
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
            let result = await PushWakeService.shared.registerCurrentDevice(role: role, deviceName: name)
            if !result.success {
                stateLog.error("PUSH-SYNC-001 Registration failed code=\(result.errorCode ?? "unknown", privacy: .public)")
            }
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "deskboard" else { return }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        guard host == "quick" || path == "/quick" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "action" })?.value?.trimmed,
              !raw.isEmpty else {
            return
        }
        triggerQuickIntentAction(raw)
    }

    func triggerQuickIntentAction(_ raw: String) {
        guard let action = quickIntentButtonAction(for: raw) else { return }
        runQuickIntentAction(action)
    }

    private func runQuickIntentAction(_ action: ButtonAction) {
        switch deviceRole {
        case .sender:
            guard connectionState.isConnected else {
                pendingQuickIntentActions.append(action)
                if pendingQuickIntentActions.count > 20 {
                    pendingQuickIntentActions.removeFirst(pendingQuickIntentActions.count - 20)
                }
                ensureConnectionActive()
                return
            }
            send(action: action, button: quickIntentButton(for: action))

        case .receiver:
            Task { @MainActor in
                _ = await executeActionAndReturnResult(action)
            }

        case .unset:
            break
        }
    }

    private func flushPendingQuickIntentActionsIfNeeded() {
        guard deviceRole == .sender, connectionState.isConnected else { return }
        guard !pendingQuickIntentActions.isEmpty else { return }
        let pending = pendingQuickIntentActions
        pendingQuickIntentActions.removeAll()
        for action in pending {
            send(action: action, button: quickIntentButton(for: action))
        }
    }

    private func quickIntentButtonAction(for raw: String) -> ButtonAction? {
        switch raw {
        case "media_play_pause":
            return .mediaPlayPause
        case "media_volume_up":
            return .mediaVolumeUp
        case "media_volume_down":
            return .mediaVolumeDown
        case "media_next":
            return .mediaNext
        case "media_previous":
            return .mediaPrevious
        default:
            return nil
        }
    }

    private func quickIntentButton(for action: ButtonAction) -> DeskButton {
        let config = ButtonConfig(
            targetPolicy: .preferReceiver,
            backgroundFallback: .relay,
            retryCount: 1,
            timeoutSeconds: 12
        )
        return DeskButton(
            title: "Quick Action",
            subtitle: "Intent",
            icon: action.systemImage,
            colorHex: "#007AFF",
            action: action,
            position: 0,
            config: config
        )
    }

    func disconnect() {
        pendingSentCommands.removeAll()
        senderButtonStates.removeAll()
        peerSession.disconnect()
    }
}

private nonisolated struct PendingSentCommand: Sendable {
    let commandID: UUID
    let buttonID: UUID
    let buttonTitle: String
    let action: ButtonAction
    var message: CommandMessage
    var attempt: Int
    let maxAttempts: Int
    let sentAt: Date
    var timeoutAt: Date
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

    func forward(
        action: ButtonAction,
        sourceDeviceName: String,
        reason: String,
        traceID: String,
        idempotencyKey: String,
        attempt: Int,
        ttlSeconds: Int?
    ) async -> RelayForwardResult {
        guard AppConfiguration.backgroundRelayEnabled else {
            return RelayForwardResult(success: false, detail: "Relay disabled", errorCode: "relay_disabled")
        }
        guard let baseURL = AppConfiguration.backgroundRelayBaseURL else {
            return RelayForwardResult(success: false, detail: "Relay URL missing", errorCode: "relay_url_missing")
        }

        let relayAction = RelayActionPayload(action: action)
        guard relayAction.kind != "none" else {
            return RelayForwardResult(success: false, detail: "No action", errorCode: "empty_action")
        }

        let body = RelayCommandRequest(
            sourceDeviceUUID: PeerSession.stableDeviceUUID,
            sourceDeviceName: sourceDeviceName,
            appVersion: AppConfiguration.appVersion,
            reason: reason,
            traceID: traceID,
            idempotencyKey: idempotencyKey,
            attempt: max(1, attempt),
            ttlSeconds: ttlSeconds,
            action: relayAction
        )

        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("v1/execute"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(idempotencyKey, forHTTPHeaderField: "x-idempotency-key")
            if let apiKey = AppConfiguration.backgroundRelayAPIKey?.trimmed, !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "x-deskboard-key")
            }
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return RelayForwardResult(success: false, detail: "Invalid relay response")
            }
            let relayResponse = try? JSONDecoder().decode(RelayExecuteResponse.self, from: data)

            if (200...299).contains(http.statusCode) {
                log.info("RELAY-001 Forwarded action=\(relayAction.kind, privacy: .public)")
                return RelayForwardResult(
                    success: true,
                    detail: relayResponse?.detail ?? "Executed via relay",
                    errorCode: nil,
                    executor: relayResponse?.executor ?? .macRelay,
                    latencyMs: relayResponse?.latencyMs
                )
            }
            log.error("RELAY-002 Relay failed status=\(http.statusCode, privacy: .public)")
            return RelayForwardResult(
                success: false,
                detail: relayResponse?.error ?? "Relay status \(http.statusCode)",
                errorCode: relayResponse?.errorCode ?? "relay_http_\(http.statusCode)"
            )
        } catch {
            log.error("RELAY-003 Relay request failed: \(String(describing: error), privacy: .public)")
            return RelayForwardResult(success: false, detail: "Relay request failed", errorCode: "relay_request_failed")
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

    @discardableResult
    func registerCurrentDevice(role: DeviceRole, deviceName: String) async -> PushWakeResult {
        guard AppConfiguration.pushWakeEnabled else {
            return .failure(errorCode: "push_wake_disabled", detail: "Push wake disabled")
        }
        guard role != .unset else {
            return .failure(errorCode: "role_unset", detail: "Device role is not set")
        }
        guard let baseURL = AppConfiguration.pushGatewayBaseURL else {
            return .failure(errorCode: "gateway_missing", detail: "Gateway URL is missing")
        }
        guard let apnsToken = AppConfiguration.pushToken?.trimmed, !apnsToken.isEmpty else {
            return .failure(errorCode: "apns_token_missing", detail: "APNs token is missing")
        }

        let payload = RegisterPayload(
            deviceUUID: PeerSession.stableDeviceUUID,
            pairingToken: PeerSession.pairingToken,
            apnsToken: apnsToken,
            role: role.rawValue,
            deviceName: deviceName.trimmed,
            appVersion: AppConfiguration.appVersion
        )

        let gatewaySignature = baseURL.absoluteString

        let signature = [
            gatewaySignature,
            payload.deviceUUID,
            payload.apnsToken,
            payload.role,
            payload.deviceName,
            payload.appVersion
        ].joined(separator: "|")

        if signature == lastRegistrationSignature,
           let lastRegistrationAt,
           Date().timeIntervalSince(lastRegistrationAt) < registrationDebounce {
            return .success(detail: "Registration is up to date")
        }

        do {
            let url = baseURL.appendingPathComponent("v1/register")
            let response = try await postJSON(url: url, body: payload)
            if (200...299).contains(response.response.statusCode) {
                lastRegistrationSignature = signature
                lastRegistrationAt = Date()
                log.info("PUSHWAKE-001 Device registration succeeded")
                return .success(detail: "Registered", statusCode: response.response.statusCode)
            }
            let parsedError = parseGatewayErrorCode(from: response.data)
            let errorCode = parsedError ?? "gateway_http_\(response.response.statusCode)"
            log.error("PUSHWAKE-002 Registration failed status=\(response.response.statusCode, privacy: .public)")
            return .failure(
                errorCode: errorCode,
                detail: "Registration failed",
                statusCode: response.response.statusCode
            )
        } catch {
            log.error("PUSHWAKE-003 Registration request failed: \(String(describing: error), privacy: .public)")
            return .failure(errorCode: "gateway_request_failed", detail: "Registration request failed")
        }
    }

    @discardableResult
    func wakePeer(targetDeviceUUID: String, reason: String) async -> PushWakeResult {
        guard AppConfiguration.pushWakeEnabled else {
            return .failure(errorCode: "push_wake_disabled", detail: "Push wake disabled")
        }
        guard let baseURL = AppConfiguration.pushGatewayBaseURL else {
            return .failure(errorCode: "gateway_missing", detail: "Gateway URL is missing")
        }
        guard !targetDeviceUUID.trimmed.isEmpty else {
            return .failure(errorCode: "target_missing", detail: "Target device UUID is missing")
        }

        let key = targetDeviceUUID.trimmed
        if let last = lastWakeAtByTarget[key], Date().timeIntervalSince(last) < wakeThrottle {
            return .failure(errorCode: "wake_throttled", detail: "Wake request throttled")
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
            if (200...299).contains(response.response.statusCode) {
                log.info("PUSHWAKE-004 Wake request succeeded for target=\(key, privacy: .public)")
                return .success(detail: "Wake sent", statusCode: response.response.statusCode)
            }
            let parsedError = parseGatewayErrorCode(from: response.data)
            let errorCode = parsedError ?? "gateway_http_\(response.response.statusCode)"
            log.error("PUSHWAKE-005 Wake request failed status=\(response.response.statusCode, privacy: .public)")
            return .failure(
                errorCode: errorCode,
                detail: "Wake request failed",
                statusCode: response.response.statusCode
            )
        } catch {
            log.error("PUSHWAKE-006 Wake request failed: \(String(describing: error), privacy: .public)")
            return .failure(errorCode: "gateway_request_failed", detail: "Wake request failed")
        }
    }

    private func postJSON<T: Encodable>(url: URL, body: T) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = AppConfiguration.pushGatewayAPIKey?.trimmed, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-deskboard-key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data: data, response: httpResponse)
    }

    private func parseGatewayErrorCode(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = object["error"] as? String {
            return error.trimmed.isEmpty ? nil : error.trimmed
        }
        return nil
    }
}

nonisolated struct PushWakeResult: Sendable {
    let success: Bool
    let errorCode: String?
    let detail: String
    let statusCode: Int?

    static func success(detail: String, statusCode: Int? = nil) -> PushWakeResult {
        PushWakeResult(success: true, errorCode: nil, detail: detail, statusCode: statusCode)
    }

    static func failure(errorCode: String, detail: String, statusCode: Int? = nil) -> PushWakeResult {
        PushWakeResult(success: false, errorCode: errorCode, detail: detail, statusCode: statusCode)
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
    let traceID: String
    let idempotencyKey: String
    let attempt: Int
    let ttlSeconds: Int?
    let action: RelayActionPayload
}

private nonisolated struct RelayExecuteResponse: Codable, Sendable {
    let ok: Bool
    let detail: String?
    let error: String?
    let errorCode: String?
    let executor: CommandExecutor?
    let latencyMs: Int?
}

nonisolated struct RelayForwardResult: Sendable {
    let success: Bool
    let detail: String?
    let errorCode: String?
    let executor: CommandExecutor
    let latencyMs: Int?

    init(
        success: Bool,
        detail: String?,
        errorCode: String? = nil,
        executor: CommandExecutor = .macRelay,
        latencyMs: Int? = nil
    ) {
        self.success = success
        self.detail = detail
        self.errorCode = errorCode
        self.executor = executor
        self.latencyMs = latencyMs
    }
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
