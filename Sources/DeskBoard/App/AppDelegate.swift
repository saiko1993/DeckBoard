import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        PeerSession.shared.stopAll()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Keep networking alive as long as platform allows
    }
}