import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_config.dart';

/// Rione scelto nel filtro della pallavolo (resta selezionato anche alle aperture successive).
const chiaveRione = 'rione_pallavolo';

/// Argomento a cui l'app si iscrive: il portale invia a tutti con quell'argomento (server/notifiche.js).
const _argomento = 'palio';

/// Notifiche push del Palio, inviate dal portale tramite Firebase Cloud Messaging: promemoria dei giorni di gara,
/// messaggi programmati e avvisi inviati subito. Uguali per tutti: nessun dato di chi usa l'app.
/// Con l'app chiusa o in secondo piano le mostra il sistema; con l'app aperta, su Android, le mostra l'app
/// (iPhone le mostra da solo). Chi non le vuole le spegne dalle impostazioni del telefono.
class Push {
  Push._();

  static final _locali = FlutterLocalNotificationsPlugin();
  static const _canale = AndroidNotificationChannel('palio', 'Notizie del Palio',
      description: 'Promemoria delle gare e avvisi degli organizzatori', importance: Importance.high);
  static bool _avviate = false;

  static Future<void> avvia() async {
    if (_avviate) return;
    _avviate = true;
    try {
      await _locali.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_notifica'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ));
      // le versioni precedenti programmavano i promemoria sul telefono: via, adesso arrivano dal portale
      await _locali.cancelAll();
      await _locali.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_canale);
      if (!firebaseConfigurato) return;

      await Firebase.initializeApp(options: opzioniFirebase);
      final fcm = FirebaseMessaging.instance;
      final permesso = await fcm.requestPermission(alert: true, sound: true, badge: false);
      if (permesso.authorizationStatus == AuthorizationStatus.denied) return;
      await fcm.setForegroundNotificationPresentationOptions(alert: true, sound: true, badge: false);
      await fcm.subscribeToTopic(_argomento);
      // con l'app aperta Android non mostra la notifica da solo
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null || defaultTargetPlatform != TargetPlatform.android) return;
        _locali.show(
          m.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(_canale.id, _canale.name,
                channelDescription: _canale.description, importance: Importance.high, priority: Priority.high, icon: 'ic_notifica'),
          ),
        );
      });
    } catch (e) {
      debugPrint('push: $e');
    }
  }
}
