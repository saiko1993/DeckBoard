import Foundation

nonisolated enum ButtonAction: Codable, Hashable, Sendable {
    case none
    case openURL(url: String)
    case sendText(text: String)
    case typeText(text: String)
    case mediaPlay
    case mediaPause
    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case mediaVolumeUp
    case mediaVolumeDown
    case mediaMute
    case presentationNext
    case presentationPrevious
    case presentationStart
    case presentationEnd
    case keyboardShortcut(modifiers: [String], key: String)
    case openDeepLink(url: String)
    case macro(actions: [ButtonAction])
    case openApp(appID: String)
    case brightnessUp
    case brightnessDown
    case lockScreen
    case runShortcut(name: String)
    case openTerminal
    case runScript(name: String)
    case toggleDarkMode
    case screenshot
    case screenRecord
    case forceQuitApp
    case emptyTrash
    case toggleDoNotDisturb
    case sleepDisplay
    case appSwitchNext
    case appSwitchPrevious
    case closeWindow
    case quitFrontApp
    case minimizeWindow
    case missionControl
    case showDesktop
    case moveSpaceLeft
    case moveSpaceRight

    var displayName: String {
        switch self {
        case .none:                 return "No Action"
        case .openURL:              return "Open URL"
        case .sendText:             return "Send Text"
        case .typeText:             return "Type Text"
        case .mediaPlay:            return "Play"
        case .mediaPause:           return "Pause"
        case .mediaPlayPause:       return "Play / Pause"
        case .mediaNext:            return "Next Track"
        case .mediaPrevious:        return "Previous Track"
        case .mediaVolumeUp:        return "Volume Up"
        case .mediaVolumeDown:      return "Volume Down"
        case .mediaMute:            return "Mute"
        case .presentationNext:     return "Next Slide"
        case .presentationPrevious: return "Previous Slide"
        case .presentationStart:    return "Start Presentation"
        case .presentationEnd:      return "End Presentation"
        case .keyboardShortcut:     return "Keyboard Shortcut"
        case .openDeepLink:         return "Open Deep Link"
        case .macro:                return "Macro"
        case .openApp(let appID):
            if let app = AppCatalog.app(withID: appID) {
                return "Open \(app.name)"
            }
            return "Open App"
        case .brightnessUp:         return "Brightness Up"
        case .brightnessDown:       return "Brightness Down"
        case .lockScreen:           return "Lock Screen"
        case .runShortcut(let name):
            return name.isEmpty ? "Run Shortcut" : "Run: \(name)"
        case .openTerminal:         return "Open Terminal"
        case .runScript(let name):
            return name.isEmpty ? "Run Script" : "Script: \(name)"
        case .toggleDarkMode:       return "Toggle Dark Mode"
        case .screenshot:           return "Screenshot"
        case .screenRecord:         return "Screen Record"
        case .forceQuitApp:         return "Force Quit App"
        case .emptyTrash:           return "Empty Trash"
        case .toggleDoNotDisturb:   return "Do Not Disturb"
        case .sleepDisplay:         return "Sleep Display"
        case .appSwitchNext:        return "Next App"
        case .appSwitchPrevious:    return "Previous App"
        case .closeWindow:          return "Close Window"
        case .quitFrontApp:         return "Quit Front App"
        case .minimizeWindow:       return "Minimize Window"
        case .missionControl:       return "Mission Control"
        case .showDesktop:          return "Show Desktop"
        case .moveSpaceLeft:        return "Move Space Left"
        case .moveSpaceRight:       return "Move Space Right"
        }
    }

    var systemImage: String {
        switch self {
        case .none:                 return "slash.circle"
        case .openURL:              return "link"
        case .sendText:             return "text.bubble"
        case .typeText:             return "text.cursor"
        case .mediaPlay:            return "play.fill"
        case .mediaPause:           return "pause.fill"
        case .mediaPlayPause:       return "playpause.fill"
        case .mediaNext:            return "forward.fill"
        case .mediaPrevious:        return "backward.fill"
        case .mediaVolumeUp:        return "speaker.plus.fill"
        case .mediaVolumeDown:      return "speaker.minus.fill"
        case .mediaMute:            return "speaker.slash.fill"
        case .presentationNext:     return "arrow.right.circle.fill"
        case .presentationPrevious: return "arrow.left.circle.fill"
        case .presentationStart:    return "play.rectangle.fill"
        case .presentationEnd:      return "stop.circle.fill"
        case .keyboardShortcut:     return "keyboard"
        case .openDeepLink:         return "arrow.up.right.circle"
        case .macro:                return "square.stack.3d.up.fill"
        case .openApp(let appID):
            if let app = AppCatalog.app(withID: appID) {
                return app.icon
            }
            return "app.fill"
        case .brightnessUp:         return "sun.max.fill"
        case .brightnessDown:       return "sun.min.fill"
        case .lockScreen:           return "lock.fill"
        case .runShortcut:          return "bolt.fill"
        case .openTerminal:         return "terminal.fill"
        case .runScript:            return "scroll.fill"
        case .toggleDarkMode:       return "circle.lefthalf.filled"
        case .screenshot:           return "camera.viewfinder"
        case .screenRecord:         return "record.circle"
        case .forceQuitApp:         return "xmark.octagon.fill"
        case .emptyTrash:           return "trash.fill"
        case .toggleDoNotDisturb:   return "moon.fill"
        case .sleepDisplay:         return "display"
        case .appSwitchNext:        return "rectangle.2.swap"
        case .appSwitchPrevious:    return "rectangle.2.swap"
        case .closeWindow:          return "xmark.square.fill"
        case .quitFrontApp:         return "power"
        case .minimizeWindow:       return "minus.square.fill"
        case .missionControl:       return "rectangle.3.group.fill"
        case .showDesktop:          return "macwindow.on.rectangle"
        case .moveSpaceLeft:        return "arrow.left.to.line"
        case .moveSpaceRight:       return "arrow.right.to.line"
        }
    }

    var category: ActionCategory {
        switch self {
        case .none, .openURL, .sendText, .typeText, .openDeepLink:
            return .general
        case .mediaPlay, .mediaPause, .mediaPlayPause, .mediaNext,
             .mediaPrevious, .mediaVolumeUp, .mediaVolumeDown, .mediaMute:
            return .media
        case .presentationNext, .presentationPrevious, .presentationStart, .presentationEnd:
            return .presentation
        case .keyboardShortcut:
            return .keyboard
        case .macro:
            return .macro
        case .openApp:
            return .apps
        case .brightnessUp, .brightnessDown, .lockScreen,
             .toggleDarkMode, .screenshot, .screenRecord,
             .forceQuitApp, .emptyTrash, .toggleDoNotDisturb, .sleepDisplay,
             .closeWindow, .quitFrontApp, .minimizeWindow, .missionControl,
             .showDesktop, .moveSpaceLeft, .moveSpaceRight:
            return .device
        case .runShortcut, .runScript, .openTerminal, .appSwitchNext, .appSwitchPrevious:
            return .shortcuts
        }
    }

    enum ActionCategory: String, CaseIterable, Sendable {
        case general      = "General"
        case media        = "Media"
        case apps         = "Apps"
        case device       = "Device"
        case shortcuts    = "Shortcuts"
        case presentation = "Presentation"
        case keyboard     = "Keyboard"
        case macro        = "Macro"

        var systemImage: String {
            switch self {
            case .general:      return "bolt.fill"
            case .media:        return "music.note"
            case .apps:         return "square.grid.2x2.fill"
            case .device:       return "ipad.and.iphone"
            case .shortcuts:    return "bolt.fill"
            case .presentation: return "rectangle.on.rectangle"
            case .keyboard:     return "keyboard"
            case .macro:        return "square.stack.3d.up.fill"
            }
        }
    }
}

extension ButtonAction {
    static var allSimpleActions: [ButtonAction] {
        [
            .none,
            .typeText(text: ""),
            .mediaPlay,
            .mediaPause,
            .mediaPlayPause,
            .mediaNext,
            .mediaPrevious,
            .mediaVolumeUp,
            .mediaVolumeDown,
            .mediaMute,
            .brightnessUp,
            .brightnessDown,
            .presentationNext,
            .presentationPrevious,
            .presentationStart,
            .presentationEnd,
            .toggleDarkMode,
            .screenshot,
            .toggleDoNotDisturb,
            .appSwitchNext,
            .appSwitchPrevious,
            .closeWindow,
            .minimizeWindow,
            .missionControl,
            .showDesktop,
            .moveSpaceLeft,
            .moveSpaceRight
        ]
    }

    var isSupportedOnIOS: Bool {
        switch self {
        case .typeText, .lockScreen, .openTerminal, .runScript,
             .screenRecord, .forceQuitApp, .emptyTrash,
             .sleepDisplay, .keyboardShortcut,
             .appSwitchNext, .appSwitchPrevious, .closeWindow,
             .quitFrontApp, .minimizeWindow, .missionControl, .showDesktop,
             .moveSpaceLeft, .moveSpaceRight:
            return false
        default:
            return true
        }
    }

    var requiresForegroundOnIOSReceiver: Bool {
        switch self {
        case .none, .sendText,
             .mediaPlay, .mediaPause, .mediaPlayPause, .mediaNext, .mediaPrevious,
             .mediaVolumeUp, .mediaVolumeDown, .mediaMute,
             .brightnessUp, .brightnessDown:
            return false

        case .openURL, .openDeepLink, .openApp, .runShortcut, .typeText,
             .presentationNext, .presentationPrevious, .presentationStart, .presentationEnd,
             .keyboardShortcut, .lockScreen, .openTerminal, .runScript,
             .toggleDarkMode, .screenshot, .screenRecord,
             .forceQuitApp, .emptyTrash, .toggleDoNotDisturb, .sleepDisplay,
             .appSwitchNext, .appSwitchPrevious, .closeWindow, .quitFrontApp,
             .minimizeWindow, .missionControl, .showDesktop, .moveSpaceLeft, .moveSpaceRight:
            return true

        case .macro(let actions):
            return actions.contains { $0.requiresForegroundOnIOSReceiver }
        }
    }

    var backgroundExecutionHint: String {
        requiresForegroundOnIOSReceiver
            ? "Needs receiver app in foreground on iOS"
            : "Can run while receiver stays in background"
    }

    var colorHex: String? {
        if case .openApp(let appID) = self {
            return AppCatalog.app(withID: appID)?.colorHex
        }
        return nil
    }

    var relayKind: String {
        switch self {
        case .none:
            return "none"
        case .openURL:
            return "open_url"
        case .openDeepLink:
            return "open_deep_link"
        case .sendText:
            return "send_text"
        case .typeText:
            return "type_text"
        case .mediaPlay:
            return "media_play"
        case .mediaPause:
            return "media_pause"
        case .mediaPlayPause:
            return "media_play_pause"
        case .mediaNext:
            return "media_next"
        case .mediaPrevious:
            return "media_previous"
        case .mediaVolumeUp:
            return "media_volume_up"
        case .mediaVolumeDown:
            return "media_volume_down"
        case .mediaMute:
            return "media_mute"
        case .presentationNext:
            return "presentation_next"
        case .presentationPrevious:
            return "presentation_previous"
        case .presentationStart:
            return "presentation_start"
        case .presentationEnd:
            return "presentation_end"
        case .keyboardShortcut:
            return "keyboard_shortcut"
        case .macro:
            return "macro"
        case .openApp:
            return "open_app"
        case .brightnessUp:
            return "brightness_up"
        case .brightnessDown:
            return "brightness_down"
        case .lockScreen:
            return "lock_screen"
        case .runShortcut:
            return "run_shortcut"
        case .openTerminal:
            return "open_terminal"
        case .runScript:
            return "run_script"
        case .toggleDarkMode:
            return "toggle_dark_mode"
        case .screenshot:
            return "screenshot"
        case .screenRecord:
            return "screen_record"
        case .forceQuitApp:
            return "force_quit_app"
        case .emptyTrash:
            return "empty_trash"
        case .toggleDoNotDisturb:
            return "toggle_dnd"
        case .sleepDisplay:
            return "sleep_display"
        case .appSwitchNext:
            return "app_switch_next"
        case .appSwitchPrevious:
            return "app_switch_previous"
        case .closeWindow:
            return "close_window"
        case .quitFrontApp:
            return "quit_front_app"
        case .minimizeWindow:
            return "minimize_window"
        case .missionControl:
            return "mission_control"
        case .showDesktop:
            return "show_desktop"
        case .moveSpaceLeft:
            return "move_space_left"
        case .moveSpaceRight:
            return "move_space_right"
        }
    }

    var isDangerousAction: Bool {
        switch self {
        case .forceQuitApp, .emptyTrash, .sleepDisplay, .lockScreen, .quitFrontApp:
            return true
        case .macro(let actions):
            return actions.contains { $0.isDangerousAction }
        default:
            return false
        }
    }
}
