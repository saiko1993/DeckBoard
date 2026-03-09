#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 16.0, *)
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
}

@available(iOS 16.0, *)
struct DeskBoardQuickMacroIntent: AppIntent {
    static let title: LocalizedStringResource = "Run DeskBoard Quick Action"
    static let description = IntentDescription("Queues a quick DeskBoard action to execute when the app becomes active.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Action")
    var action: DeskBoardQuickIntentAction

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(action.rawValue, forKey: AppConfiguration.Keys.pendingIntentAction)
        return .result()
    }
}

#endif
