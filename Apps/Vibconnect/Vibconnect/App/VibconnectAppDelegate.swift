import FirebaseCore
import UIKit

final class VibconnectAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    Self.configureFirebaseIfNeeded()
    return true
  }

  static func configureFirebaseIfNeeded() {
    guard FirebaseApp.app() == nil else { return }

    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let options = FirebaseOptions(contentsOfFile: path)
    {
      FirebaseApp.configure(options: options)
      return
    }

    FirebaseApp.configure()
  }
}
