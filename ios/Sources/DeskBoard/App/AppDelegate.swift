import UIKit
@preconcurrency import BackgroundTasks
import os.log

final class AppDelegate: NSObject, UIApplicationDelegate {

    nonisolated private static let bgTaskID = "com.deskboard.connection-keepalive"
    nonisolated private static let appLog = Logger(subsystem: "com.deskboard", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let role = AppConfiguration.deviceRole
        if role == .sender || role == .receiver {
            application.isIdleTimerDisabled = true
        }

        registerBackgroundTask()
        application.registerForRemoteNotifications()
        Self.scheduleBGRefresh()
        return true
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskID, using: .main) { task in
            guard let bgTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.performBGRefresh(bgTask)
        }
    }

    nonisolated func applicationWillTerminate(_ application: UIApplication) {
        Task { @MainActor in
            PeerSession.shared.stopAll()
        }
    }

    nonisolated func applicationDidEnterBackground(_ application: UIApplication) {
        Self.scheduleBGRefresh()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        AppConfiguration.pushToken = token
        Self.appLog.info("PUSH-001 Registered APNs token")
        Task {
            let result = await PushWakeService.shared.registerCurrentDevice(
                role: AppConfiguration.deviceRole,
                deviceName: AppConfiguration.deviceName
            )
            if !result.success {
                Self.appLog.error("PUSH-003 Initial registration failed code=\(result.errorCode ?? "unknown", privacy: .public)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Self.appLog.error("PUSH-002 APNs registration failed: \(String(describing: error), privacy: .public)")
    }

    @MainActor
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let deskboard = userInfo["deskboard"] as? [String: Any],
              (deskboard["kind"] as? String) == "wake" else {
            completionHandler(.noData)
            return
        }

        let session = PeerSession.shared
        guard AppConfiguration.autoReconnect else {
            completionHandler(.noData)
            return
        }

        if !session.isConnected {
            session.attemptQuickReconnect()
            completionHandler(.newData)
            return
        }

        completionHandler(.noData)
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
            if AppConfiguration.autoReconnect && !session.isConnected {
                session.attemptQuickReconnect()
            }
            task.setTaskCompleted(success: true)
        }
        scheduleBGRefresh()
    }
}
