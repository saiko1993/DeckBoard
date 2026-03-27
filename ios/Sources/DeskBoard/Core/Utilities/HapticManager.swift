import Foundation
import UIKit

// MARK: - HapticManager

@MainActor
final class HapticManager: @unchecked Sendable {

    static let shared = HapticManager()
    private init() {}

    // MARK: - Impact

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    func light()  { impact(.light) }
    func medium() { impact(.medium) }
    func heavy()  { impact(.heavy) }

    // MARK: - Selection

    func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }

    // MARK: - Notification

    func success() { notification(.success) }
    func warning() { notification(.warning) }
    func error()   { notification(.error) }

    private func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }
}