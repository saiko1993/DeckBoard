#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 18.0, *)
enum DeskBoardQuickIntentAction: String, CaseIterable, AppEnum {
    case playPause = "media_play_pause"
    case volumeUp = "media_volume_up"
    case volumeDown = "media_volume_down"
    case nextTrack = "media_next"
    case previousTrack = "media_previous"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "DeskBoard Quick Action")
    static let caseDisplayRepresentations: [DeskBoardQuickIntentAction: DisplayRepresentation] = [
        .playPause: DisplayRepresentation(title: "Play/Pause"),
        .volumeUp: DisplayRepresentation(title: "Volume Up"),
        .volumeDown: DisplayRepresentation(title: "Volume Down"),
        .nextTrack: DisplayRepresentation(title: "Next Track"),
        .previousTrack: DisplayRepresentation(title: "Previous Track")
    ]

    var title: String {
        switch self {
        case .playPause:
            return "Play/Pause"
        case .volumeUp:
            return "Volume Up"
        case .volumeDown:
            return "Volume Down"
        case .nextTrack:
            return "Next Track"
        case .previousTrack:
            return "Previous Track"
        }
    }

    var systemImageName: String {
        switch self {
        case .playPause:
            return "playpause.fill"
        case .volumeUp:
            return "speaker.plus.fill"
        case .volumeDown:
            return "speaker.minus.fill"
        case .nextTrack:
            return "forward.fill"
        case .previousTrack:
            return "backward.fill"
        }
    }

    var deepLinkURL: URL {
        URL(string: "deskboard://quick?action=\(rawValue)")!
    }
}

@available(iOS 18.0, *)
struct DeskBoardQuickMacroIntent: AppIntent {
    static let title: LocalizedStringResource = "Run DeskBoard Quick Action"
    static let description = IntentDescription("Runs a quick DeskBoard action through app intents.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Action")
    var action: DeskBoardQuickIntentAction

    init() {}

    init(action: DeskBoardQuickIntentAction) {
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        return .result(opensIntent: OpenURLIntent(action.deepLinkURL))
    }
}

#endif
