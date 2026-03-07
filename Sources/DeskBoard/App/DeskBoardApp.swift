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
                .onChange(of: scenePhase) { newPhase in
                    handleScenePhase(newPhase)
                }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            break
        case .active:
            if case .disconnected = appState.connectionState {
                appState.reconnect()
            } else if case .idle = appState.connectionState {
                appState.reconnect()
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}