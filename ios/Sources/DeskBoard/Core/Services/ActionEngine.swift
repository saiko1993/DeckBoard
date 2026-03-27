import Foundation
import UIKit

@MainActor
final class ActionEngine: ObservableObject {

    static let shared = ActionEngine()

    @Published private(set) var buttonStates: [UUID: ButtonExecutionState] = [:]
    @Published private(set) var executionLogs: [ExecutionLog] = []

    private let maxLogs = 200
    private let logStore = ExecutionLogStore.shared
    private let httpService = HTTPActionService.shared

    private init() {
        executionLogs = logStore.load()
    }

    func execute(button: DeskButton, config: ButtonConfig = ButtonConfig()) async {
        guard button.isEnabled else { return }

        if case .cooldown(let until) = buttonStates[button.id], until > Date() {
            return
        }

        if case .running = buttonStates[button.id] {
            return
        }

        buttonStates[button.id] = .running
        let startTime = Date()

        let result = await performAction(button.action)
        let duration = Date().timeIntervalSince(startTime)

        switch result {
        case .success:
            buttonStates[button.id] = .success
            if config.cooldownSeconds > 0 {
                let cooldownEnd = Date().addingTimeInterval(config.cooldownSeconds)
                buttonStates[button.id] = .cooldown(until: cooldownEnd)
                Task {
                    try? await Task.sleep(for: .seconds(config.cooldownSeconds))
                    if case .cooldown = self.buttonStates[button.id] {
                        self.buttonStates[button.id] = .idle
                    }
                }
            } else {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    if case .success = self.buttonStates[button.id] {
                        self.buttonStates[button.id] = .idle
                    }
                }
            }
        case .failure:
            buttonStates[button.id] = .failed(result.displayText)
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                if case .failed = self.buttonStates[button.id] {
                    self.buttonStates[button.id] = .idle
                }
            }
        default:
            buttonStates[button.id] = .idle
        }

        let log = ExecutionLog(
            buttonID: button.id,
            buttonTitle: button.title,
            action: button.action,
            result: result,
            duration: duration
        )
        addLog(log)
    }

    func executeLocal(action: ButtonAction) async -> ExecutionResult {
        await performAction(action)
    }

    func stateFor(_ buttonID: UUID) -> ButtonExecutionState {
        buttonStates[buttonID] ?? .idle
    }

    func clearLogs() {
        executionLogs.removeAll()
        logStore.clear()
    }

    func resetState(_ buttonID: UUID) {
        buttonStates[buttonID] = .idle
    }

    private func addLog(_ log: ExecutionLog) {
        executionLogs.insert(log, at: 0)
        if executionLogs.count > maxLogs {
            executionLogs = Array(executionLogs.prefix(maxLogs))
        }
        logStore.append(log)
    }

    private func performAction(_ action: ButtonAction) async -> ExecutionResult {
        let media = MediaControlService.shared
        switch action {
        case .none:
            return .success(detail: nil)

        case .openURL(let urlString):
            return await openURL(urlString)

        case .openDeepLink(let urlString):
            return await openURL(urlString)

        case .sendText(let text):
            UIPasteboard.general.string = text
            return .success(detail: "Copied to clipboard")

        case .typeText:
            return .failure(error: "Type text is not supported on iOS receiver")

        case .mediaVolumeUp:
            media.volumeUp()
            return .success(detail: "Volume Up")

        case .mediaVolumeDown:
            media.volumeDown()
            return .success(detail: "Volume Down")

        case .mediaMute:
            media.mute()
            return .success(detail: "Muted")

        case .brightnessUp:
            media.brightnessUp()
            return .success(detail: "Brightness Up")

        case .brightnessDown:
            media.brightnessDown()
            return .success(detail: "Brightness Down")

        case .openApp(let appID):
            let opened = await media.openAppByID(appID)
            if opened {
                let name = AppCatalog.app(withID: appID)?.name ?? appID
                return .success(detail: "Opened \(name)")
            } else {
                return .failure(error: "App not installed")
            }

        case .runShortcut(let name):
            let opened = await media.runShortcut(name: name)
            return opened ? .success(detail: "Running \(name)") : .failure(error: "Could not run shortcut")

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
            return .success(detail: "Next Track")

        case .mediaPrevious:
            media.mediaPrevious()
            return .success(detail: "Previous Track")

        case .presentationNext:
            let opened = await media.runShortcut(name: "Next Slide")
            return opened ? .success(detail: "Next slide") : .failure(error: "Could not run shortcut")

        case .presentationPrevious:
            let opened = await media.runShortcut(name: "Previous Slide")
            return opened ? .success(detail: "Previous slide") : .failure(error: "Could not run shortcut")

        case .presentationStart:
            let opened = await media.runShortcut(name: "Start Presentation")
            return opened ? .success(detail: "Start presentation") : .failure(error: "Could not run shortcut")

        case .presentationEnd:
            let opened = await media.runShortcut(name: "End Presentation")
            return opened ? .success(detail: "End presentation") : .failure(error: "Could not run shortcut")

        case .keyboardShortcut(let modifiers, let key):
            return .failure(error: "Keyboard shortcut is not supported on iOS receiver (\(modifiers.joined(separator: "+"))+\(key))")

        case .lockScreen:
            return .failure(error: "Lock screen is not supported on iOS receiver")

        case .openTerminal:
            let opened = await media.openTerminal()
            return opened ? .success(detail: "Opened Terminal") : .failure(error: "Could not open Terminal")

        case .runScript(let name):
            let opened = await media.runScript(name: name)
            return opened ? .success(detail: "Running \(name)") : .failure(error: "Could not run script")

        case .toggleDarkMode:
            let toggled = await media.toggleDarkMode()
            return toggled ? .success(detail: "Toggled Dark Mode") : .failure(error: "Could not toggle")

        case .screenshot:
            let taken = await media.takeScreenshot()
            return taken ? .success(detail: "Screenshot taken") : .failure(error: "Could not take screenshot")

        case .screenRecord:
            let toggled = await media.toggleScreenRecord()
            return toggled ? .success(detail: "Screen recording toggled") : .failure(error: "Could not toggle recording")

        case .forceQuitApp:
            let quit = await media.forceQuitFrontApp()
            return quit ? .success(detail: "Force quit") : .failure(error: "Could not force quit")

        case .emptyTrash:
            let emptied = await media.emptyTrash()
            return emptied ? .success(detail: "Trash emptied") : .failure(error: "Could not empty trash")

        case .toggleDoNotDisturb:
            let toggled = await media.toggleDoNotDisturb()
            return toggled ? .success(detail: "Do Not Disturb toggled") : .failure(error: "Could not toggle DND")

        case .sleepDisplay:
            let slept = await media.sleepDisplay()
            return slept ? .success(detail: "Display sleeping") : .failure(error: "Could not sleep display")

        case .appSwitchNext:
            return .failure(error: "App switch is not supported on iOS receiver")

        case .appSwitchPrevious:
            return .failure(error: "App switch is not supported on iOS receiver")

        case .closeWindow:
            return .failure(error: "Close window is not supported on iOS receiver")

        case .quitFrontApp:
            return .failure(error: "Quit app is not supported on iOS receiver")

        case .minimizeWindow:
            return .failure(error: "Minimize window is not supported on iOS receiver")

        case .missionControl:
            return .failure(error: "Mission Control is not supported on iOS receiver")

        case .showDesktop:
            return .failure(error: "Show desktop is not supported on iOS receiver")

        case .moveSpaceLeft:
            return .failure(error: "Move space is not supported on iOS receiver")

        case .moveSpaceRight:
            return .failure(error: "Move space is not supported on iOS receiver")

        case .macro(let actions):
            return await executeMacro(actions)
        }
    }

    private func openURL(_ urlString: String) async -> ExecutionResult {
        guard !urlString.isEmpty else {
            return .failure(error: "Empty URL")
        }
        guard let url = URL(string: urlString) else {
            return .failure(error: "Invalid URL: \(urlString)")
        }

        let opened = await UIApplication.shared.open(url)
        if opened {
            return .success(detail: "Opened \(urlString)")
        } else {
            return .failure(error: "Could not open URL")
        }
    }

    func executeHTTPAction(_ config: ActionPayload.HTTPRequestConfig) async -> ExecutionResult {
        do {
            let response = try await httpService.execute(config: config)
            if (200...299).contains(response.statusCode) {
                return .success(detail: "HTTP \(response.statusCode)")
            } else {
                return .failure(error: "HTTP \(response.statusCode)")
            }
        } catch {
            return .failure(error: error.localizedDescription)
        }
    }

    private func executeMacro(_ actions: [ButtonAction]) async -> ExecutionResult {
        for (index, action) in actions.enumerated() {
            let result = await performAction(action)
            if case .failure(let error) = result {
                return .failure(error: "Step \(index + 1) failed: \(error)")
            }
        }
        return .success(detail: "All \(actions.count) steps completed")
    }
}
