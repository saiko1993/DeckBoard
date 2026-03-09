import SwiftUI
import WidgetKit

@main
struct DeskBoardControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 18.0, *) {
            DeskBoardQuickActionsWidget()
            DeskBoardPlayPauseControlWidget()
            DeskBoardNextTrackControlWidget()
            DeskBoardVolumeUpControlWidget()
        }
    }
}
