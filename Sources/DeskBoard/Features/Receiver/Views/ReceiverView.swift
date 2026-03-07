import SwiftUI

struct ReceiverView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        _ReceiverViewWrapper(appState: appState)
    }
}

private struct _ReceiverViewWrapper: View {
    @StateObject private var viewModel: ReceiverViewModel

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: ReceiverViewModel(appState: appState))
    }

    var body: some View {
        _ReceiverViewBody()
            .environmentObject(viewModel)
    }
}

private struct _ReceiverViewBody: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: ReceiverViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ConnectionStatusRow(state: viewModel.connectionState)
                }

                if let command = viewModel.lastCommand {
                    Section("Last Command") {
                        IncomingCommandView(command: command)
                    }
                }

                if !viewModel.commandHistory.isEmpty {
                    Section("History") {
                        ForEach(viewModel.commandHistory) { command in
                            CommandHistoryRow(command: command)
                        }
                    }
                } else if viewModel.lastCommand == nil {
                    Section {
                        emptyState
                    }
                }

                Section("Allowed Actions") {
                    ForEach(ButtonAction.ActionCategory.allCases, id: \.self) { category in
                        Toggle(isOn: Binding(
                            get: { viewModel.allowedActions.contains(category) },
                            set: { viewModel.setAllowed(category: category, allowed: $0) }
                        )) {
                            Label(category.rawValue, systemImage: category.systemImage)
                        }
                    }
                }
            }
            .navigationTitle("Receiver")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { viewModel.clearHistory() }
                        .disabled(viewModel.commandHistory.isEmpty)
                }
            }
        }
        .task { viewModel.startListening() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("Waiting for commands")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .listRowBackground(Color.clear)
    }
}

// MARK: - ConnectionStatusRow

private struct ConnectionStatusRow: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.systemImage)
                .foregroundStyle(stateColor)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.displayTitle)
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if state.isConnected {
                Circle().fill(Color.green).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var stateColor: Color {
        switch state {
        case .connected:    return .green
        case .searching:    return .blue
        case .pairing:      return .orange
        case .error:        return .red
        default:            return .secondary
        }
    }

    private var statusSubtitle: String {
        switch state {
        case .idle:          return "Start by pairing a sender device"
        case .searching:     return "Looking for nearby sender devices"
        case .found(let n):  return "Found \(n)"
        case .pairing:       return "Exchanging credentials"
        case .connected:     return "Ready to receive commands"
        case .disconnected:  return "Tap Connect to reconnect"
        case .error(let m):  return m
        }
    }
}

private struct CommandHistoryRow: View {
    let command: CommandMessage

    var body: some View {
        HStack(spacing: 10) {
            if case .buttonAction(let action) = command.payload {
                Image(systemName: action.systemImage)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.displayName).font(.subheadline)
                    Text(command.timestamp.relativeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}