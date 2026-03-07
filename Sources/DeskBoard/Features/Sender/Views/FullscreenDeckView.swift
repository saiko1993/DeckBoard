import SwiftUI

struct FullscreenDeckView: View {
    let dashboard: Dashboard
    let page: DashboardPage
    let onButtonTap: (DeskButton) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showControls: Bool = true

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: page.layoutColumns)
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if showControls {
                        topBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(page.buttons.sorted(by: { $0.position < $1.position })) { button in
                                StreamDeckButton(button: button) {
                                    onButtonTap(button)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }

                    if showControls {
                        bottomControls
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.3)) {
                    showControls.toggle()
                }
            }
        }
        .statusBarHidden(!showControls)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Text(dashboard.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text(page.title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
    }

    private var bottomControls: some View {
        HStack(spacing: 24) {
            VolumeKnobView(label: "VOL") { direction in
                let action: ButtonAction = direction == .up ? .mediaVolumeUp : .mediaVolumeDown
                let fakeButton = DeskButton(title: "Volume", action: action)
                onButtonTap(fakeButton)
            }

            Spacer()

            VolumeKnobView(label: "NAV") { direction in
                let action: ButtonAction = direction == .up ? .mediaNext : .mediaPrevious
                let fakeButton = DeskButton(title: "Nav", action: action)
                onButtonTap(fakeButton)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.6))
    }
}

// MARK: - Stream Deck Button

struct StreamDeckButton: View {
    let button: DeskButton
    let onTap: () -> Void

    @State private var isPressed: Bool = false
    @State private var pressDepth: CGFloat = 0

    var body: some View {
        Button {
            triggerPress()
            onTap()
        } label: {
            buttonContent
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .rotation3DEffect(
            .degrees(pressDepth * 2),
            axis: (x: 0.3, y: 0.3, z: 0)
        )
        .opacity(button.isEnabled ? 1.0 : 0.35)
    }

    private var buttonContent: some View {
        VStack(spacing: 6) {
            if let url = button.resolvedIconURL {
                Color.clear
                    .frame(width: 36, height: 36)
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
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text(button.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(button.color.gradient)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .clear, .black.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: button.color.opacity(isPressed ? 0.1 : 0.5), radius: isPressed ? 2 : 8, y: isPressed ? 1 : 4)
    }

    private func triggerPress() {
        HapticManager.shared.medium()
        withAnimation(.spring(duration: 0.08)) {
            isPressed = true
            pressDepth = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = false
                pressDepth = 0
            }
        }
    }
}
