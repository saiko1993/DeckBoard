import Foundation
import Combine

@MainActor
final class ButtonEditorViewModel: ObservableObject {

    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var icon: String = "star.fill"
    @Published var colorHex: String = "#007AFF"
    @Published var selectedAction: ButtonAction = .none
    @Published var hapticFeedback: Bool = true
    @Published var isEnabled: Bool = true

    @Published var urlText: String = ""
    @Published var textPayload: String = ""
    @Published var appID: String = ""

    @Published var shortcutKey: String = ""
    @Published var shortcutModifiers: [String] = []
    @Published var shortcutName: String = ""
    @Published var iconURL: String = ""
    @Published var buttonShape: DeskButtonShape = .roundedRectangle
    @Published var sizePreset: DeskButtonSizePreset = .medium
    @Published var dragLocked: Bool = false

    @Published var confirmBeforeExecute: Bool = false
    @Published var cooldownSeconds: Double = 0
    @Published var cornerRadius: Double = 14
    @Published var iconScale: Double = 1.0
    @Published var targetPolicy: ActionTargetPolicy = .preferReceiver
    @Published var backgroundFallback: BackgroundFallbackPolicy = .relay
    @Published var retryCount: Double = 1
    @Published var timeoutSeconds: Double = 12

    var isValid: Bool {
        !title.trimmed.isEmpty
    }

    var resolvedAction: ButtonAction {
        resolveAction()
    }

    init() {}

    convenience init(button: DeskButton) {
        self.init()
        populate(from: button)
    }

    func populate(from button: DeskButton) {
        title = button.title
        subtitle = button.subtitle ?? ""
        icon = button.icon
        colorHex = button.colorHex
        hapticFeedback = button.hapticFeedback
        isEnabled = button.isEnabled
        selectedAction = button.action
        iconURL = button.iconURL ?? ""
        buttonShape = button.buttonShape
        sizePreset = button.sizePreset
        dragLocked = button.dragLocked
        confirmBeforeExecute = button.config.confirmBeforeExecute
        cooldownSeconds = button.config.cooldownSeconds
        cornerRadius = button.config.cornerRadius
        iconScale = button.config.iconScale
        targetPolicy = button.config.targetPolicy
        backgroundFallback = button.config.backgroundFallback
        retryCount = Double(button.config.retryCount)
        timeoutSeconds = button.config.timeoutSeconds
        extractPayloads(from: button.action)
    }

    private func extractPayloads(from action: ButtonAction) {
        switch action {
        case .openURL(let url), .openDeepLink(let url):
            urlText = url
        case .sendText(let text):
            textPayload = text
        case .openApp(let appID):
            self.appID = appID
        case .keyboardShortcut(let mods, let key):
            shortcutModifiers = mods
            shortcutKey = key
        case .typeText(let text):
            textPayload = text
        case .runShortcut(let name):
            shortcutName = name
        case .runScript(let name):
            shortcutName = name
        default:
            break
        }
    }

    func autoFillFromApp(appID: String) {
        guard let app = AppCatalog.app(withID: appID) else { return }
        self.appID = appID
        if title.trimmed.isEmpty {
            title = app.name
        }
        icon = app.icon
        colorHex = app.colorHex
    }

    func buildButton(id: UUID = UUID(), position: Int = 0) -> DeskButton {
        let resolvedAction = resolveAction()
        let config = ButtonConfig(
            confirmBeforeExecute: confirmBeforeExecute,
            cooldownSeconds: cooldownSeconds,
            longPressAction: nil,
            showStatusIndicator: true,
            cornerRadius: cornerRadius,
            iconScale: iconScale,
            subtitle: subtitle.trimmed.isEmpty ? nil : subtitle.trimmed,
            targetPolicy: targetPolicy,
            backgroundFallback: backgroundFallback,
            retryCount: Int(retryCount.rounded()),
            timeoutSeconds: timeoutSeconds
        )
        return DeskButton(
            id: id,
            title: title.trimmed,
            subtitle: subtitle.trimmed.isEmpty ? nil : subtitle.trimmed,
            icon: icon,
            colorHex: colorHex,
            action: resolvedAction,
            hapticFeedback: hapticFeedback,
            position: position,
            isEnabled: isEnabled,
            iconURL: iconURL.trimmed.isEmpty ? nil : iconURL.trimmed,
            buttonShape: buttonShape,
            sizePreset: sizePreset,
            dragLocked: dragLocked,
            config: config
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
        case .typeText:
            return textPayload.trimmed.isEmpty ? .none : .typeText(text: textPayload.trimmed)
        case .openApp(let currentID):
            let resolvedAppID = appID.trimmed.isEmpty ? currentID.trimmed : appID.trimmed
            return resolvedAppID.isEmpty ? .none : .openApp(appID: resolvedAppID)
        case .keyboardShortcut:
            return shortcutKey.trimmed.isEmpty ? .none : .keyboardShortcut(modifiers: shortcutModifiers, key: shortcutKey.trimmed)
        case .runShortcut:
            return shortcutName.trimmed.isEmpty ? .none : .runShortcut(name: shortcutName.trimmed)
        case .runScript:
            return shortcutName.trimmed.isEmpty ? .none : .runScript(name: shortcutName.trimmed)
        default:
            return selectedAction
        }
    }

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
        "hand.wave.fill", "person.fill", "globe",
        "command", "option", "shift", "delete.left.fill",
        "power", "moon.fill", "sun.max.fill",
        "wifi", "airplane", "light.max",
        "camera.fill", "paintbrush.fill", "scissors"
    ]

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
        ("Black",  "#1C1C1E"),
        ("Indigo", "#5856D6"),
        ("Mint",   "#00C7BE"),
        ("Brown",  "#A2845E"),
        ("Cyan",   "#32ADE6"),
        ("Charcoal", "#2C2C2E")
    ]
}
