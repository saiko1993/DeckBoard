import UIKit
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {

    nonisolated private static let bgTaskID = "com.deskboard.connection-keepalive"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let role = AppConfiguration.deviceRole
        if role == .sender || role == .receiver {
            application.isIdleTimerDisabled = true
        }
        registerBackgroundTask()
        return true
    }

    private func registerBackgroundTask() {
        do {
            try BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskID, using: .main) { task in
                guard let bgTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                Self.performBGRefresh(bgTask)
            }
        } catch {
            print("BGTask registration failed: \(error)")
        }
    }

    nonisolated func applicationWillTerminate(_ application: UIApplication) {
        DispatchQueue.main.async {
            PeerSession.shared.stopAll()
        }
    }

    nonisolated func applicationDidEnterBackground(_ application: UIApplication) {
        DispatchQueue.main.async {
            PeerSession.shared.enterBackground()
        }
        Self.scheduleBGRefresh()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        PeerSession.shared.enterForeground()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    nonisolated private static func scheduleBGRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated private static func performBGRefresh(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        DispatchQueue.main.async {
            let session = PeerSession.shared
            if !session.isConnected {
                session.attemptQuickReconnect()
            }
            task.setTaskCompleted(success: true)
        }
        scheduleBGRefresh()
    }
}
