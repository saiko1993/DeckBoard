import SwiftUI

struct DeskButtonView: View {
    let button: DeskButton
    let isEditMode: Bool
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
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .opacity(button.isEnabled ? 1.0 : 0.4)
        .overlay(alignment: .topTrailing) {
            if isEditMode {
                editOverlay
            }
        }
        .contextMenu {
            contextMenuContent
        }
    }

    // MARK: - Button Label

    private var buttonLabel: some View {
        VStack(spacing: 8) {
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
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: button.icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
            }

            Text(button.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(button.color)
                .shadow(color: button.color.opacity(0.4), radius: 6, y: 3)
        )
    }

    // MARK: - Edit Mode Overlay

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

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}