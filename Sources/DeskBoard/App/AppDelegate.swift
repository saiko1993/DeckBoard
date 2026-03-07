import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var keepAliveTimer: DispatchSourceTimer?
    private let keepAliveQueue = DispatchQueue(label: "com.deskboard.keepalive", qos: .userInitiated)
    private var cachedDeviceName: String = ""

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let role = AppConfiguration.deviceRole
        cachedDeviceName = AppConfiguration.deviceName
        if role == .sender || role == .receiver {
            application.isIdleTimerDisabled = true
        }
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        stopKeepAlive()
        let session = PeerSession.shared
        let name = cachedDeviceName
        let msg = CommandMessage(type: .disconnect, payload: .disconnect, senderID: name)
        session.send(command: msg)
        Thread.sleep(forTimeInterval: 0.5)
        session.stopAll()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        cachedDeviceName = AppConfiguration.deviceName
        beginBackgroundTask(application)
        startKeepAlive()
        PeerSession.shared.enterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        stopKeepAlive()
        endBackgroundTask()
        PeerSession.shared.enterForeground()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func beginBackgroundTask(_ application: UIApplication) {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = application.beginBackgroundTask(withName: "DeskBoardPeerAlive") { [weak self] in
            self?.renewBackgroundTask()
        }
    }

    private func renewBackgroundTask() {
        let app = UIApplication.shared
        let oldID = backgroundTaskID
        backgroundTaskID = .invalid

        backgroundTaskID = app.beginBackgroundTask(withName: "DeskBoardPeerAlive") { [weak self] in
            self?.renewBackgroundTask()
        }

        if oldID != .invalid {
            app.endBackgroundTask(oldID)
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func startKeepAlive() {
        stopKeepAlive()
        let deviceName = cachedDeviceName
        let timer = DispatchSource.makeTimerSource(queue: keepAliveQueue)
        timer.schedule(deadline: .now() + 3.0, repeating: 8.0, leeway: .seconds(1))
        timer.setEventHandler {
            DispatchQueue.main.async {
                let session = PeerSession.shared
                if session.isConnected {
                    let msg = CommandMessage(type: .heartbeat, payload: .heartbeat, senderID: deviceName)
                    session.send(command: msg)
                } else {
                    session.restartServices()
                }
            }
        }
        timer.resume()
        keepAliveTimer = timer
    }

    private func stopKeepAlive() {
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
    }
}
