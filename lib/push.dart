import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'apri_pagina.dart';
import 'firebase_config.dart';

/// Rione scelto nel filtro della pallavolo (resta selezionato anche alle aperture successive).
const chiaveRione = 'rione_pallavolo';

/// Argomento a cui l'app si iscrive: il portale invia a tutti con quell'argomento (server/notifiche.js).
const _argomento = 'palio';

/// Notifiche push del Palio, inviate dal portale tramite Firebase Cloud Messaging: promemoria dei giorni di gara,
/// messaggi programmati e avvisi inviati subito. Uguali per tutti: nessun dato di chi usa l'app.
/// Con l'app chiusa o in secondo piano le mostra il sistema; con l'app aperta, su Android, le mostra l'app
/// (iPhone le mostra da solo). Chi non le vuole le spegne dalle impostazioni del telefono.
/// Toccando la notifica si apre la pagina scelta nel pannello (dati «pagina», apri_pagina.dart).
class Push {
  Push._();

  static final _locali = FlutterLocalNotificationsPlugin();
  static const _canale = AndroidNotificationChannel('palio', 'Notizie del Palio',
      description: 'Promemoria delle gare e avvisi degli organizzatori', importance: Importance.high);
  static bool _avviate = false;

  // nelle compilazioni per le schermate dello store (scripts/schermate.sh, --dart-define=SCHERMATA=...) niente push:
  // la richiesta del permesso coprirebbe la pagina
  static const _schermata = String.fromEnvironment('SCHERMATA');

  static Future<void> avvia() async {
    if (_avviate || _schermata.isNotEmpty) return;
    _avviate = true;
    try {
      await _locali.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_notifica'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ), onDidReceiveNotificationResponse: (r) {
        // tocco sulla notifica mostrata dall'app aperta (Android): i dati sono nel payload
        final p = r.payload;
        if (p != null && p.isNotEmpty) apriPagina(Map<String, dynamic>.from(jsonDecode(p) as Map));
      });
      // le versioni precedenti programmavano i promemoria sul telefono: via, adesso arrivano dal portale
      await _locali.cancelAll();
      await _locali.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_canale);
      if (!firebaseConfigurato) return;

      await Firebase.initializeApp(options: opzioniFirebase);
      final fcm = FirebaseMessaging.instance;
      // tocco sulla notifica: con l'app in secondo piano, oppure chiusa (l'app si apre da li')
      FirebaseMessaging.onMessageOpenedApp.listen((m) => apriPagina(m.data));
      final iniziale = await fcm.getInitialMessage();
      if (iniziale != null) apriPagina(iniziale.data);
      final permesso = await fcm.requestPermission(alert: true, sound: true, badge: false);
      if (permesso.authorizationStatus == AuthorizationStatus.denied) return;
      await fcm.setForegroundNotificationPresentationOptions(alert: true, sound: true, badge: false);
      // iPhone: l'iscrizione all'argomento richiede il token APNs, che Apple consegna qualche istante dopo il permesso;
      // senza aspettarlo l'iscrizione fallisce («apns-token-not-set») e il telefono non riceve nulla
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var i = 0; i < 30 && await fcm.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      await fcm.subscribeToTopic(_argomento);
      // solo nelle prove: il token per mandare una notifica a questo telefono soltanto
      if (kDebugMode) debugPrint('push: token ${await fcm.getToken()}');
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
          payload: jsonEncode(m.data),
        );
      });
    } catch (e) {
      debugPrint('push: $e');
    }
  }
}
