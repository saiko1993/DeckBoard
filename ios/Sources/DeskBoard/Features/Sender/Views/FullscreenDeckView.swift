import SwiftUI

struct FullscreenDeckView: View {
    let dashboard: Dashboard
    let page: DashboardPage
    let onButtonTap: (DeskButton) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showControls: Bool = true
    @State private var showInputPanel: Bool = false
    @State private var typedText: String = ""

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: page.layoutColumns)
    }

    private var visibleKnobs: [DeckKnobConfig] {
        let knobs = page.knobs.filter(\.isVisible)
        let source = knobs.isEmpty ? DashboardPage.defaultKnobs : knobs
        let order: [DeckKnobPlacement: Int] = [.leading: 0, .center: 1, .trailing: 2]
        return source.sorted { lhs, rhs in
            let lo = order[lhs.placement] ?? 1
            let ro = order[rhs.placement] ?? 1
            if lo == ro {
                return lhs.label < rhs.label
            }
            return lo < ro
        }
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

                    HStack(spacing: 0) {
                        deckBody

                        if showInputPanel {
                            inputPanel
                                .frame(width: 280)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
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
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Text(dashboard.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    showInputPanel.toggle()
                }
            } label: {
                Image(systemName: showInputPanel ? "keyboard.chevron.compact.down" : "keyboard.badge.eye")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .overlay(alignment: .center) {
            Text(page.title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .offset(y: 18)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.62))
    }

    @ViewBuilder
    private var deckBody: some View {
        if page.layoutMode == .grid {
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
        } else {
            ScrollView([.vertical, .horizontal]) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(page.buttons.enumerated()), id: \.element.id) { index, button in
                        let frame = button.buttonFrame ?? defaultFreeformFrame(index: index)
                        StreamDeckButton(button: button) {
                            onButtonTap(button)
                        }
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
                    }
                }
                .frame(width: 1400, height: 900, alignment: .topLeading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keyboard & Mouse")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                TextField("Type text on Mac", text: $typedText, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)

                Button {
                    let trimmed = typedText.trimmed
                    guard !trimmed.isEmpty else { return }
                    executeAux(action: .typeText(text: trimmed), title: "Type Text")
                } label: {
                    Label("Send Text", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                panelButton(title: "Next App", icon: "rectangle.2.swap", action: .appSwitchNext)
                panelButton(title: "Prev App", icon: "rectangle.2.swap", action: .appSwitchPrevious)
                panelButton(title: "Close", icon: "xmark.square.fill", action: .closeWindow)
                panelButton(title: "Minimize", icon: "minus.square.fill", action: .minimizeWindow)
                panelButton(title: "Mission", icon: "rectangle.3.group.fill", action: .missionControl)
                panelButton(title: "Desktop", icon: "macwindow.on.rectangle", action: .showDesktop)
                panelButton(title: "Space ◀", icon: "arrow.left.to.line", action: .moveSpaceLeft)
                panelButton(title: "Space ▶", icon: "arrow.right.to.line", action: .moveSpaceRight)
            }

            GesturePadView { action in
                executeAux(action: action, title: action.displayName)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
    }

    private var bottomControls: some View {
        HStack(spacing: 14) {
            ForEach(visibleKnobs) { knob in
                VolumeKnobView(
                    label: knob.label,
                    knobSize: CGFloat(knob.size),
                    stepThreshold: knob.stepThreshold,
                    hapticStyle: knob.hapticStyle
                ) { direction in
                    let action = direction == .up ? knob.clockwiseAction : knob.counterClockwiseAction
                    executeAux(action: action, title: knob.label)
                } onPress: {
                    if let press = knob.pressAction {
                        executeAux(action: press, title: knob.label)
                    }
                } onLongPress: {
                    if let hold = knob.longPressAction {
                        executeAux(action: hold, title: knob.label)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.62))
    }

    private func executeAux(action: ButtonAction, title: String) {
        let fakeButton = DeskButton(title: title, action: action)
        onButtonTap(fakeButton)
    }

    private func panelButton(title: String, icon: String, action: ButtonAction) -> some View {
        Button {
            executeAux(action: action, title: title)
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue.opacity(0.85))
    }

    private func defaultFreeformFrame(index: Int) -> DeckButtonFrame {
        let columns = max(2, page.layoutColumns)
        let spacing: Double = 14
        let size: Double = 100
        let row = index / columns
        let col = index % columns
        return DeckButtonFrame(
            x: Double(col) * (size + spacing) + spacing,
            y: Double(row) * (size + spacing) + spacing,
            width: size,
            height: size,
            zIndex: Double(index)
        )
    }
}

private struct GesturePadView: View {
    let onAction: (ButtonAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gesture Pad")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .frame(height: 120)
                .overlay {
                    Text("Swipe: Apps/Desktop\nTap: Play/Pause")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onEnded { value in
                            let translation = value.translation
                            let absX = abs(translation.width)
                            let absY = abs(translation.height)

                            if absX < 14 && absY < 14 {
                                onAction(.mediaPlayPause)
                            } else if absX > absY {
                                onAction(translation.width > 0 ? .appSwitchPrevious : .appSwitchNext)
                            } else {
                                onAction(translation.height > 0 ? .showDesktop : .missionControl)
                            }
                        }
                )
                .onTapGesture {
                    onAction(.mediaPlayPause)
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    onAction(.closeWindow)
                }
        }
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
