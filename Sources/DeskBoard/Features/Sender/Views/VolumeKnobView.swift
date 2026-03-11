import SwiftUI

nonisolated enum KnobDirection: Sendable {
    case up, down
}

struct VolumeKnobView: View {
    let label: String
    var knobSize: CGFloat = 56
    var stepThreshold: Double = 15
    var hapticStyle: DeckKnobHapticStyle = .selection
    let onTurn: (KnobDirection) -> Void
    var onPress: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    @State private var rotation: Double = 0
    @State private var lastAngle: Double = 0
    @State private var accumulatedDelta: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(.systemGray3), Color(.systemGray6), Color(.systemGray4)],
                            center: .center,
                            startRadius: 2,
                            endRadius: knobSize / 2
                        )
                    )
                    .frame(width: knobSize, height: knobSize)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .black.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: knobSize, height: knobSize)

                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .offset(y: -(knobSize / 2 - 10))
                    .rotationEffect(.degrees(rotation))

                ForEach(0..<12, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 4)
                        .offset(y: -(knobSize / 2 - 4))
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: knobSize / 2, y: knobSize / 2)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let angle = atan2(dy, dx) * 180 / .pi

                        let delta = angleDelta(from: lastAngle, to: angle)
                        lastAngle = angle
                        accumulatedDelta += delta

                        withAnimation(.interactiveSpring()) {
                            rotation += delta
                        }

                        if abs(accumulatedDelta) >= stepThreshold {
                            let direction: KnobDirection = accumulatedDelta > 0 ? .up : .down
                            onTurn(direction)
                            accumulatedDelta = 0
                            emitHaptic()
                        }
                    }
                    .onEnded { _ in
                        accumulatedDelta = 0
                    }
            )
            .onTapGesture {
                onPress?()
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                onLongPress?()
            }

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func angleDelta(from: Double, to: Double) -> Double {
        var d = to - from
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    private func emitHaptic() {
        switch hapticStyle {
        case .off:
            break
        case .selection:
            HapticManager.shared.selection()
        case .light:
            HapticManager.shared.light()
        case .medium:
            HapticManager.shared.medium()
        case .heavy:
            HapticManager.shared.heavy()
        }
    }
}
