import Foundation
import Combine

@MainActor
final class ButtonEditorViewModel: ObservableObject {

    // MARK: - Button Fields

    @Published var title: String = ""
    @Published var icon: String = "star.fill"
    @Published var colorHex: String = "#007AFF"
    @Published var selectedAction: ButtonAction = .none
    @Published var hapticFeedback: Bool = true
    @Published var isEnabled: Bool = true

    // URL / Text payload
    @Published var urlText: String = ""
    @Published var textPayload: String = ""

    // Keyboard shortcut
    @Published var shortcutKey: String = ""
    @Published var shortcutModifiers: [String] = []
    @Published var iconURL: String = ""

    // MARK: - Validation

    var isValid: Bool {
        !title.trimmed.isEmpty
    }

    // MARK: - Init

    init() {}

    convenience init(button: DeskButton) {
        self.init()
        populate(from: button)
    }

    // MARK: - Populate from existing button

    func populate(from button: DeskButton) {
        title = button.title
        icon = button.icon
        colorHex = button.colorHex
        hapticFeedback = button.hapticFeedback
        isEnabled = button.isEnabled
        selectedAction = button.action
        iconURL = button.iconURL ?? ""
        extractPayloads(from: button.action)
    }

    private func extractPayloads(from action: ButtonAction) {
        switch action {
        case .openURL(let url), .openDeepLink(let url):
            urlText = url
        case .sendText(let text):
            textPayload = text
        case .keyboardShortcut(let mods, let key):
            shortcutModifiers = mods
            shortcutKey = key
        default:
            break
        }
    }

    // MARK: - Build Button

    func buildButton(id: UUID = UUID(), position: Int = 0) -> DeskButton {
        let resolvedAction = resolveAction()
        return DeskButton(
            id: id,
            title: title.trimmed,
            icon: icon,
            colorHex: colorHex,
            action: resolvedAction,
            hapticFeedback: hapticFeedback,
            position: position,
            isEnabled: isEnabled,
            iconURL: iconURL.trimmed.isEmpty ? nil : iconURL.trimmed
        )
    }

    func buildUpdatedButton(from original: DeskButton) -> DeskButton {
        buildButton(id: original.id, position: original.position)
    }

    private func resolveAction() -> ButtonAction {
        switch selectedAction {
        case .openURL:
            return urlText.trimmed.isEmpty ? .none : .openURL(url: urlText.trimmed)
        case .openDeepLink:
            return urlText.trimmed.isEmpty ? .none : .openDeepLink(url: urlText.trimmed)
        case .sendText:
            return textPayload.trimmed.isEmpty ? .none : .sendText(text: textPayload.trimmed)
        case .keyboardShortcut:
            return shortcutKey.trimmed.isEmpty ? .none : .keyboardShortcut(modifiers: shortcutModifiers, key: shortcutKey.trimmed)
        default:
            return selectedAction
        }
    }

    // MARK: - Common Icons

    static let commonIcons: [String] = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "play.fill", "pause.fill", "forward.fill", "backward.fill",
        "playpause.fill", "speaker.plus.fill", "speaker.minus.fill",
        "arrow.right.circle.fill", "arrow.left.circle.fill",
        "link", "text.bubble", "keyboard",
        "music.note", "video.fill", "mic.fill",
        "photo.fill", "doc.fill", "folder.fill",
        "magnifyingglass", "house.fill", "gearshape.fill",
        "bell.fill", "clock.fill", "calendar",
        "checkmark.circle.fill", "xmark.circle.fill",
        "exclamationmark.triangle.fill", "info.circle.fill",
        "rectangle.on.rectangle", "square.stack.3d.up.fill",
        "stop.circle.fill", "play.rectangle.fill",
        "hand.wave.fill", "person.fill", "globe"
    ]

    // MARK: - Preset Colors

    static let presetColors: [(name: String, hex: String)] = [
        ("Blue",   "#007AFF"),
        ("Green",  "#34C759"),
        ("Orange", "#FF9500"),
        ("Red",    "#FF3B30"),
        ("Purple", "#AF52DE"),
        ("Pink",   "#FF2D55"),
        ("Teal",   "#30B0C7"),
        ("Yellow", "#FFD60A"),
        ("Gray",   "#636366"),
        ("Black",  "#1C1C1E")
    ]
}