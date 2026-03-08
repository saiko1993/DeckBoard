import SwiftUI

@main
struct DeskBoardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase)
                }
                .task {
                    try? await Task.sleep(for: .milliseconds(300))
                    appState.ensureConnectionActive()
                }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            UIApplication.shared.isIdleTimerDisabled = true
            appState.handleBecameActive()
        case .inactive:
            break
        case .background:
            appState.handleEnteredBackground()
        @unknown default:
            break
        }
    }
}
