import SwiftUI

struct ExecutionLogView: View {
    @State private var logs: [ExecutionLog] = []

    var body: some View {
        List {
            if logs.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No execution history yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(logs) { log in
                    LogEntryRow(log: log)
                }
            }
        }
        .navigationTitle("Execution History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") {
                    ExecutionLogStore.shared.clear()
                    logs = []
                }
                .disabled(logs.isEmpty)
            }
        }
        .onAppear {
            logs = ExecutionLogStore.shared.load()
        }
    }
}

private struct LogEntryRow: View {
    let log: ExecutionLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.result.systemImage)
                .foregroundStyle(resultColor)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(log.buttonTitle)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(log.action.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(log.result.displayText)
                        .font(.caption)
                        .foregroundStyle(resultColor)
                }
                Text(log.timestamp.relativeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if log.duration > 0 {
                Text(String(format: "%.0fms", log.duration * 1000))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var resultColor: Color {
        switch log.result {
        case .success: return .green
        case .failure: return .red
        case .timeout: return .orange
        case .cancelled: return .secondary
        case .pending: return .blue
        }
    }
}
