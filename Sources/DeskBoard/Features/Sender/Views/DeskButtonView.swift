import SwiftUI

struct DeskButtonView: View {
    let button: DeskButton
    let isEditMode: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false
    @ObservedObject private var engine = ActionEngine.shared

    private var executionState: ButtonExecutionState {
        engine.stateFor(button.id)
    }

    var body: some View {
        Button {
            if isEditMode {
                onEdit()
            } else {
                withAnimation(.spring(duration: 0.1)) { isPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(duration: 0.2)) { isPressed = false }
                }
                onTap()
            }
        } label: {
            buttonLabel
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .opacity(button.isEnabled ? 1.0 : 0.4)
        .overlay(alignment: .topTrailing) {
            if isEditMode {
                editOverlay
            }
        }
        .overlay(alignment: .bottomTrailing) {
            statusIndicator
        }
        .contextMenu {
            contextMenuContent
        }
    }

    private var buttonLabel: some View {
        VStack(spacing: 6) {
            if let url = button.resolvedIconURL {
                Color.clear
                    .frame(width: 32, height: 32)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .allowsHitTesting(false)
                            case .failure:
                                Image(systemName: button.icon)
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(.white)
                            default:
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                    .clipShape(.rect(cornerRadius: 6))
            } else {
                Image(systemName: button.icon)
                    .font(.system(size: 22 * button.config.iconScale, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
            }

            Text(button.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            if let subtitle = button.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: button.config.cornerRadius, style: .continuous)
                .fill(button.color)
                .shadow(color: button.color.opacity(0.4), radius: 6, y: 3)
        )
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if button.config.showStatusIndicator {
            switch executionState {
            case .running:
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(.white)
                    .padding(4)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(4)
                    .transition(.scale.combined(with: .opacity))
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(4)
                    .transition(.scale.combined(with: .opacity))
            case .cooldown:
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(4)
            default:
                EmptyView()
            }
        }
    }

    private var editOverlay: some View {
        HStack(spacing: 4) {
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .blue)
                    .shadow(radius: 2)
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .red)
                    .shadow(radius: 2)
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            onTap()
        } label: {
            Label("Execute", systemImage: "play.fill")
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
