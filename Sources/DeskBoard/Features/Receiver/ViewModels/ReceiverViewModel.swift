import Foundation
import Combine

@MainActor
final class ReceiverViewModel: ObservableObject {

    @Published var connectionState: ConnectionState = .idle
    @Published var lastCommand: CommandMessage?
    @Published var commandHistory: [CommandMessage] = []
    @Published var allowedActions: Set<ButtonAction.ActionCategory> = Set(ButtonAction.ActionCategory.allCases)
    @Published var silentMode: Bool = false

    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        bind()
    }

    private func bind() {
        appState.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        appState.$lastReceivedCommand
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] command in
                self?.handleCommand(command)
            }
            .store(in: &cancellables)

        appState.$silentReceiver
            .receive(on: DispatchQueue.main)
            .assign(to: &$silentMode)
    }

    private func handleCommand(_ command: CommandMessage) {
        // Check if this action category is allowed
        if case .buttonAction(let action) = command.payload {
            guard allowedActions.contains(action.category) else { return }
        }
        lastCommand = command
        commandHistory.insert(command, at: 0)
        if commandHistory.count > 50 {
            commandHistory = Array(commandHistory.prefix(50))
        }
    }

    func clearHistory() {
        commandHistory = []
        lastCommand = nil
    }

    func startListening() {
        appState.reconnect()
    }

    func setAllowed(category: ButtonAction.ActionCategory, allowed: Bool) {
        if allowed {
            allowedActions.insert(category)
        } else {
            allowedActions.remove(category)
        }
    }
}