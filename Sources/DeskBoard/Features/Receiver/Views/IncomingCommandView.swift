import SwiftUI
import UIKit

// MARK: - IncomingCommandView

struct IncomingCommandView: View {
    let command: CommandMessage

    @State private var copyFeedback = false

    var body: some View {
        if case .buttonAction(let action) = command.payload {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(actionColor(action).opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: action.systemImage)
                            .foregroundStyle(actionColor(action))
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.displayName)
                            .font(.headline)
                        Text("From: \(command.senderID)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(command.timestamp.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Text payload
                if case .sendText(let text) = action {
                    Divider()
                    HStack {
                        Text(text)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            UIPasteboard.general.string = text
                            withAnimation { copyFeedback = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copyFeedback = false }
                            }
                        } label: {
                            Label(copyFeedback ? "Copied!" : "Copy",
                                  systemImage: copyFeedback ? "checkmark" : "doc.on.doc")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // URL payload
                if case .openURL(let url) = action {
                    Divider()
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func actionColor(_ action: ButtonAction) -> Color {
        switch action.category {
        case .media:        return .purple
        case .presentation: return .red
        case .keyboard:     return .orange
        case .macro:        return .indigo
        case .general:      return .blue
        }
    }
}