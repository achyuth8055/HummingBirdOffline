import UIKit
import FirebaseCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@objcMembers
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase as early as possible during launch so the default app is available
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Additional setup after Firebase is configured can go here.
        return true
    }

    #if canImport(GoogleSignIn)
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    #endif
}
