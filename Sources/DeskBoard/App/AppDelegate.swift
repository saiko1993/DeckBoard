import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.isIdleTimerDisabled = false
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        PeerSession.shared.stopAll()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        beginBackgroundTask(application)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        endBackgroundTask()
    }

    private func beginBackgroundTask(_ application: UIApplication) {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = application.beginBackgroundTask(withName: "DeskBoardPeerSession") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}