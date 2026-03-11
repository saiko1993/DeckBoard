import SwiftUI

struct DeskButtonView: View {
    let button: DeskButton
    let isEditMode: Bool
    let executionState: ButtonExecutionState
    var enforceAspectRatio: Bool = true
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false

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
            if let badge = executionState.badgeText, !isEditMode {
                Text(badge)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(stateBadgeColor)
                    )
                    .padding(8)
            }
        }
        .contextMenu {
            contextMenuContent
        }
    }

    private var buttonLabel: some View {
        Group {
            if enforceAspectRatio {
                contentBody.aspectRatio(1, contentMode: .fit)
            } else {
                contentBody.frame(maxHeight: .infinity)
            }
        }
        .padding(10)
        .background(
            Group {
                switch button.buttonShape {
                case .roundedRectangle:
                    RoundedRectangle(cornerRadius: button.config.cornerRadius, style: .continuous)
                        .fill(button.color)
                case .capsule:
                    Capsule()
                        .fill(button.color)
                case .circle:
                    Circle()
                        .fill(button.color)
                }
            }
            .shadow(color: stateShadowColor, radius: 7, y: 3)
        )
    }

    private var contentBody: some View {
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

    private var stateBadgeColor: Color {
        switch executionState {
        case .running:
            return .blue
        case .queued:
            return .orange
        case .success:
            return .green
        case .failed:
            return .red
        case .cooldown:
            return .secondary
        case .idle:
            return .clear
        }
    }

    private var stateShadowColor: Color {
        switch executionState {
        case .success:
            return Color.green.opacity(0.45)
        case .failed:
            return Color.red.opacity(0.45)
        case .queued:
            return Color.orange.opacity(0.45)
        case .running:
            return Color.blue.opacity(0.45)
        case .idle, .cooldown:
            return button.color.opacity(0.4)
        }
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
