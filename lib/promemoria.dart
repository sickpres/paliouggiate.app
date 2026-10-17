import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';
import 'models.dart';
import 'widgets/comuni.dart';

/// Rione scelto nel filtro della pallavolo: serve anche ai promemoria.
const chiaveRione = 'rione_pallavolo';

/// Promemoria delle gare: notifiche locali programmate sul telefono a partire dal piano del portale
/// (GET /api/notifiche, al massimo una al giorno). Senza account Apple a pagamento non ci sono push dal server:
/// il piano si riscarica e si riprograma a ogni apertura dell'app e quando cambia il rione scelto.
class Promemoria {
  Promemoria._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pronto = false;
  static Future<void>? _inCorso;

  static Future<void> _inizializza() async {
    if (_pronto) return;
    tzdata.initializeTimeZones();
    // il permesso si chiede solo quando c'e' davvero qualcosa da programmare
    await _plugin.initialize(const InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _pronto = true;
  }

  /// Riscarica il piano e riprograma le notifiche. Non segnala errori: senza rete restano quelle di prima.
  static Future<void> aggiorna() => _inCorso ??= _aggiorna().whenComplete(() => _inCorso = null);

  static Future<void> _aggiorna() async {
    try {
      final piano = await Api.instance.notifiche();
      await _inizializza();
      if (piano.isEmpty) {
        await _plugin.cancelAll();
        return;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final permesso = await ios?.requestPermissions(alert: true, sound: true) ?? false;
      if (!permesso) return;

      int? rione;
      try {
        rione = (await SharedPreferences.getInstance()).getInt(chiaveRione);
      } catch (_) {
        rione = null;
      }
      final rioni = {for (final r in await rioniInCache()) r.id: r.nome};

      await _plugin.cancelAll();
      var id = 0;
      for (final n in piano) {
        await _plugin.zonedSchedule(
          id++,
          n.titolo,
          testoPer(n, rione, rioni),
          tz.TZDateTime.from(n.quando.toUtc(), tz.UTC),
          const NotificationDetails(iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('promemoria: $e');
    }
  }

  /// Testo del promemoria; se il rione scelto gioca o arbitra una partita di pallavolo quel giorno, la si aggiunge.
  @visibleForTesting
  static String testoPer(Notifica n, int? rione, Map<int, String> rioni) {
    if (rione == null || n.partite.isEmpty) return n.testo;
    final nome = rioni[rione];
    if (nome == null) return n.testo;
    final extra = <String>[];
    for (final p in n.partite) {
      if (p.rioneA == rione || p.rioneB == rione) {
        final avversario = rioni[p.rioneA == rione ? p.rioneB : p.rioneA] ?? '?';
        extra.add('alle ${p.ora} $nome gioca contro $avversario');
      } else if (p.arbitro == rione) {
        extra.add('alle ${p.ora} $nome arbitra ${rioni[p.rioneA] ?? '?'}–${rioni[p.rioneB] ?? '?'}');
      }
    }
    return extra.isEmpty ? n.testo : '${n.testo} Pallavolo: ${extra.join('; ')}.';
  }
}
