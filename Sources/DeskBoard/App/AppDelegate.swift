import UIKit
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {

    private static let bgTaskID = "com.deskboard.connection-keepalive"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let role = AppConfiguration.deviceRole
        if role == .sender || role == .receiver {
            application.isIdleTimerDisabled = true
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskID, using: .main) { task in
            guard let bgTask = task as? BGAppRefreshTask else { return }
            self.handleBGRefresh(bgTask)
        }
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        let session = PeerSession.shared
        let name = AppConfiguration.deviceName
        let msg = CommandMessage(type: .disconnect, payload: .disconnect, senderID: name)
        session.send(command: msg)
        Thread.sleep(forTimeInterval: 0.3)
        session.stopAll()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        PeerSession.shared.enterBackground()
        scheduleBGRefresh()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        PeerSession.shared.enterForeground()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func scheduleBGRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBGRefresh(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        let session = PeerSession.shared
        if session.isConnected {
            let name = AppConfiguration.deviceName
            let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: name)
            session.send(command: msg)
        }
        task.setTaskCompleted(success: true)
        scheduleBGRefresh()
    }
}
