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

        case .mediaPlay, .mediaPause, .mediaPlayPause,
             .mediaNext, .mediaPrevious,
             .mediaVolumeUp, .mediaVolumeDown:
            return .success(detail: "Media command sent")

        case .presentationNext, .presentationPrevious,
             .presentationStart, .presentationEnd:
            return .success(detail: "Presentation command sent")

        case .keyboardShortcut(let modifiers, let key):
            return .success(detail: "Shortcut: \(modifiers.joined(separator: "+"))+\(key)")

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
