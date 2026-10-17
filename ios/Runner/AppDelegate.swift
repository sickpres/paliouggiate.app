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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Chiave di Google Maps: non e' scritta nell'app, arriva dal portale (Amministrazione sistema). Dart la passa qui
    // prima di aprire la prima mappa. GMSServices si chiama per nome, cosi' l'app non dipende dal modulo GoogleMaps.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PalioMappa") else { return }
    let canale = FlutterMethodChannel(name: "palio/mappa", binaryMessenger: registrar.messenger())
    canale.setMethodCallHandler { chiamata, risposta in
      guard chiamata.method == "impostaChiave", let chiave = chiamata.arguments as? String, !chiave.isEmpty else {
        risposta(FlutterMethodNotImplemented)
        return
      }
      guard let servizi = NSClassFromString("GMSServices") as AnyObject? else {
        risposta(FlutterError(code: "mappa", message: "Google Maps non disponibile", details: nil))
        return
      }
      // restituisce un BOOL, non un oggetto: il valore non si legge
      _ = servizi.perform(NSSelectorFromString("provideAPIKey:"), with: chiave)
      risposta(true)
    }
  }
}
