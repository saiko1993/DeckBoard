import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
private struct DeskBoardQuickEntry: TimelineEntry {
    let date: Date
}

@available(iOSApplicationExtension 18.0, *)
private struct DeskBoardQuickProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeskBoardQuickEntry {
        DeskBoardQuickEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DeskBoardQuickEntry) -> Void) {
        completion(DeskBoardQuickEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeskBoardQuickEntry>) -> Void) {
        let entry = DeskBoardQuickEntry(date: Date())
        let next = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct DeskBoardQuickActionsWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                quickButton(.playPause)
                quickButton(.nextTrack)
            }
            HStack(spacing: 8) {
                quickButton(.volumeUp)
                quickButton(.volumeDown)
            }
        }
        .padding(10)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func quickButton(_ action: DeskBoardQuickIntentAction) -> some View {
        Button(intent: DeskBoardQuickMacroIntent(action: action)) {
            Image(systemName: action.systemImageName)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct DeskBoardQuickActionsWidget: Widget {
    let kind: String = "com.deskboard.widget.quickactions"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DeskBoardQuickProvider()) { _ in
            DeskBoardQuickActionsWidgetView()
        }
        .configurationDisplayName("DeskBoard Quick Actions")
        .description("Run common DeskBoard actions from Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
