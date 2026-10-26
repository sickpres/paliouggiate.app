import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // promemoria delle gare: mostrati anche con l'app aperta (flutter_local_notifications)
    UNUserNotificationCenter.current().delegate = self
    // il «1» sull'icona messo dalle push del portale sparisce appena si apre l'app; le notifiche restano nel Centro notifiche.
    // La notifica di sistema arriva sia con le scene sia senza
    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
      UNUserNotificationCenter.current().setBadgeCount(0)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
