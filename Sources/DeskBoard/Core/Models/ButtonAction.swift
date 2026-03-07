import Foundation

// MARK: - ButtonAction

enum ButtonAction: Codable, Hashable, Sendable {
    case none
    case openURL(url: String)
    case sendText(text: String)
    case mediaPlay
    case mediaPause
    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case mediaVolumeUp
    case mediaVolumeDown
    case presentationNext
    case presentationPrevious
    case presentationStart
    case presentationEnd
    case keyboardShortcut(modifiers: [String], key: String)
    case openDeepLink(url: String)
    case macro(actions: [ButtonAction])

    var displayName: String {
        switch self {
        case .none:                 return "No Action"
        case .openURL:              return "Open URL"
        case .sendText:             return "Send Text"
        case .mediaPlay:            return "Play"
        case .mediaPause:           return "Pause"
        case .mediaPlayPause:       return "Play / Pause"
        case .mediaNext:            return "Next Track"
        case .mediaPrevious:        return "Previous Track"
        case .mediaVolumeUp:        return "Volume Up"
        case .mediaVolumeDown:      return "Volume Down"
        case .presentationNext:     return "Next Slide"
        case .presentationPrevious: return "Previous Slide"
        case .presentationStart:    return "Start Presentation"
        case .presentationEnd:      return "End Presentation"
        case .keyboardShortcut:     return "Keyboard Shortcut"
        case .openDeepLink:         return "Open Deep Link"
        case .macro:                return "Macro"
        }
    }

    var systemImage: String {
        switch self {
        case .none:                 return "slash.circle"
        case .openURL:              return "link"
        case .sendText:             return "text.bubble"
        case .mediaPlay:            return "play.fill"
        case .mediaPause:           return "pause.fill"
        case .mediaPlayPause:       return "playpause.fill"
        case .mediaNext:            return "forward.fill"
        case .mediaPrevious:        return "backward.fill"
        case .mediaVolumeUp:        return "speaker.plus.fill"
        case .mediaVolumeDown:      return "speaker.minus.fill"
        case .presentationNext:     return "arrow.right.circle.fill"
        case .presentationPrevious: return "arrow.left.circle.fill"
        case .presentationStart:    return "play.rectangle.fill"
        case .presentationEnd:      return "stop.circle.fill"
        case .keyboardShortcut:     return "keyboard"
        case .openDeepLink:         return "arrow.up.right.circle"
        case .macro:                return "square.stack.3d.up.fill"
        }
    }

    var category: ActionCategory {
        switch self {
        case .none, .openURL, .sendText, .openDeepLink:
            return .general
        case .mediaPlay, .mediaPause, .mediaPlayPause, .mediaNext,
             .mediaPrevious, .mediaVolumeUp, .mediaVolumeDown:
            return .media
        case .presentationNext, .presentationPrevious, .presentationStart, .presentationEnd:
            return .presentation
        case .keyboardShortcut:
            return .keyboard
        case .macro:
            return .macro
        }
    }

    // MARK: - ActionCategory

    enum ActionCategory: String, CaseIterable, Sendable {
        case general      = "General"
        case media        = "Media"
        case presentation = "Presentation"
        case keyboard     = "Keyboard"
        case macro        = "Macro"

        var systemImage: String {
            switch self {
            case .general:      return "bolt.fill"
            case .media:        return "music.note"
            case .presentation: return "rectangle.on.rectangle"
            case .keyboard:     return "keyboard"
            case .macro:        return "square.stack.3d.up.fill"
            }
        }
    }
}

// MARK: - All Actions (flat list for pickers)

extension ButtonAction {
    static var allSimpleActions: [ButtonAction] {
        [
            .none,
            .mediaPlay,
            .mediaPause,
            .mediaPlayPause,
            .mediaNext,
            .mediaPrevious,
            .mediaVolumeUp,
            .mediaVolumeDown,
            .presentationNext,
            .presentationPrevious,
            .presentationStart,
            .presentationEnd
        ]
    }
}