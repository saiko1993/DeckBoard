import SwiftUI

struct IntentControlsView: View {
    @EnvironmentObject var appState: AppState

    private struct QuickActionUI: Identifiable {
        let rawValue: String
        let title: String
        let systemImageName: String
        var id: String { rawValue }

        var deepLinkURL: String {
            "deskboard://quick?action=\(rawValue)"
        }
    }

    private let quickActions: [QuickActionUI] = [
        QuickActionUI(rawValue: "media_play_pause", title: "Play/Pause", systemImageName: "playpause.fill"),
        QuickActionUI(rawValue: "media_next", title: "Next Track", systemImageName: "forward.fill"),
        QuickActionUI(rawValue: "media_previous", title: "Previous Track", systemImageName: "backward.fill"),
        QuickActionUI(rawValue: "media_volume_up", title: "Volume Up", systemImageName: "speaker.plus.fill"),
        QuickActionUI(rawValue: "media_volume_down", title: "Volume Down", systemImageName: "speaker.minus.fill")
    ]

    var body: some View {
        List {
            Section("Intent-driven Actions") {
                ForEach(quickActions) { action in
                    HStack(spacing: 12) {
                        Image(systemName: action.systemImageName)
                            .foregroundStyle(.blue)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(.subheadline.weight(.semibold))
                            Text(action.deepLinkURL)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Run") {
                            appState.triggerQuickIntentAction(action.rawValue)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Notes") {
                Text("These actions are exposed to App Intents, widgets, and Control Center controls.")
                Text("When this device is Sender and disconnected, actions are queued until connection resumes.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Intent Controls")
        .navigationBarTitleDisplayMode(.inline)
    }
}
