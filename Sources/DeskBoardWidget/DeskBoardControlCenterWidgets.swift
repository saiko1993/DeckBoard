import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct DeskBoardPlayPauseControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.deskboard.control.playpause") {
            ControlWidgetButton(action: DeskBoardQuickMacroIntent(action: .playPause)) {
                Label("Play/Pause", systemImage: "playpause.fill")
            }
        }
        .displayName("DeskBoard Play/Pause")
        .description("Trigger DeskBoard play/pause action.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct DeskBoardNextTrackControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.deskboard.control.next") {
            ControlWidgetButton(action: DeskBoardQuickMacroIntent(action: .nextTrack)) {
                Label("Next Track", systemImage: "forward.fill")
            }
        }
        .displayName("DeskBoard Next")
        .description("Trigger DeskBoard next-track action.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct DeskBoardVolumeUpControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.deskboard.control.volumeup") {
            ControlWidgetButton(action: DeskBoardQuickMacroIntent(action: .volumeUp)) {
                Label("Volume Up", systemImage: "speaker.plus.fill")
            }
        }
        .displayName("DeskBoard Volume Up")
        .description("Trigger DeskBoard volume-up action.")
    }
}
