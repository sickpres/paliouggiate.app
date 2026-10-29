import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';

// «Il Tesoro del Palio» (server/tesoro.js del portale): il giocatore non ha un account, solo un gettone casuale
// salvato sul telefono e mandato nell'header X-Giocatore. Disinstallando l'app il gettone si perde e si ricomincia.
const _kGettone = 'tesoro_gettone';

typedef Json = Map<String, dynamic>;

class TesoroApi {
  TesoroApi._();
  static final TesoroApi instance = TesoroApi._();
  static const _timeout = Duration(seconds: 20);
  final _client = http.Client();
  String? _gettone;
  bool _letto = false;

  Future<bool> iscritto() async {
    if (!_letto) {
      _gettone = (await SharedPreferences.getInstance()).getString(_kGettone);
      _letto = true;
    }
    return _gettone != null;
  }

  Future<void> _salva(String? g) async {
    _gettone = g;
    final p = await SharedPreferences.getInstance();
    g == null ? await p.remove(_kGettone) : await p.setString(_kGettone, g);
  }

  Map<String, String> get intestazioni => {if (_gettone != null) 'X-Giocatore': _gettone!};
  String indirizzo(String percorso) => '$baseUrl$percorso';

  Future<dynamic> _chiama(String metodo, String percorso, [Object? corpo]) async {
    final uri = Uri.parse('$baseUrl/api/tesoro$percorso');
    final h = {'Accept': 'application/json', 'Content-Type': 'application/json', ...intestazioni};
    final http.Response r;
    try {
      final body = corpo == null ? null : jsonEncode(corpo);
      r = await switch (metodo) {
        'POST' => _client.post(uri, headers: h, body: body ?? '{}'),
        'PUT' => _client.put(uri, headers: h, body: body ?? '{}'),
        'DELETE' => _client.delete(uri, headers: h),
        _ => _client.get(uri, headers: h),
      }.timeout(_timeout);
    } on TimeoutException {
      throw ApiException(0, 'Il server non risponde. Riprova tra poco.');
    } on SocketException {
      throw ApiException(0, 'Connessione assente. Controlla la rete e riprova.');
    } on http.ClientException {
      throw ApiException(0, 'Connessione non riuscita. Riprova tra poco.');
    }
    dynamic data;
    try {
      data = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 400) {
      // gettone sconosciuto (giocatore cancellato o gioco azzerato): si ricomincia dall'iscrizione
      if (r.statusCode == 401) await _salva(null);
      throw ApiException(r.statusCode, data is Map && data['errore'] is String ? data['errore'] as String : 'Errore del server (${r.statusCode})');
    }
    return data;
  }

  Json _m(dynamic d) => Map<String, dynamic>.from(d as Map);

  Future<Json> config() async => _m(await _chiama('GET', ''));
  Future<List<Json>> avatar() async => [for (final x in await _chiama('GET', '/avatar') as List) _m(x)];
  Future<Json> classifica() async => _m(await _chiama('GET', '/classifica'));
  Future<List<Json>> amici() async => [for (final x in await _chiama('GET', '/amici') as List) _m(x)];

  Future<Json> iscrivi({required int avatar, required int rione, String invito = ''}) async {
    final r = _m(await _chiama('POST', '/giocatore', {'avatar_id': avatar, 'rione_id': rione, if (invito.trim().isNotEmpty) 'invito': invito.trim()}));
    await _salva(r['gettone'] as String);
    return r;
  }

  Future<Json> io() async => _m(await _chiama('GET', '/io'));
  Future<Json> modifica(Json campi) async => _m(await _chiama('PUT', '/io', campi));
  Future<void> ricomincia() async {
    await _chiama('DELETE', '/io');
    await _salva(null);
  }

  Future<Json> iniziaSfida(String gioco) async => _m(await _chiama('POST', '/sfide/$gioco', {}));
  Future<Json> fineSfida(String gioco, String partita) async => _m(await _chiama('POST', '/sfide/$gioco', {'partita': partita}));
  Future<Json> occhio(String codice, Json pos, int foto) async => _m(await _chiama('POST', '/occhio', {'codice': codice, 'foto_id': foto, ...pos}));
  Future<Json> enigma(String parola) async => _m(await _chiama('POST', '/enigma', {'parola': parola}));
  Future<Json> tavolo(String azione, [Json corpo = const {}]) async => _m(await _chiama('POST', '/tavolo/$azione', corpo));
  Future<Json> tesoro(String codice) async => _m(await _chiama('POST', '/tesoro', {'codice': codice}));

  /// Manda la foto a pezzi (il portale accetta richieste fino a 32 KB) e ne restituisce l'id.
  Future<int> caricaFoto(String prova, List<int> byte) async {
    const pezzo = 24 * 1024;
    final dati = base64Encode(byte);
    final codice = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 30).toRadixString(36)}';
    final totale = (dati.length / pezzo).ceil();
    Json r = {};
    for (var i = 0; i < totale; i++) {
      r = _m(await _chiama('PUT', '/foto/$prova',
          {'codice': codice, 'indice': i, 'totale': totale, 'dati': dati.substring(i * pezzo, math.min(dati.length, (i + 1) * pezzo))}));
    }
    return (r['id'] as num).toInt();
  }
}

// ---------- posizione, fotocamera e QR ----------

class PermessoNegato implements Exception {
  final String messaggio;
  PermessoNegato(this.messaggio);
  @override
  String toString() => messaggio;
}

/// Stato del permesso di posizione, senza chiederlo (per l'avviso della pagina del gioco).
Future<bool> posizioneBloccata() async {
  final p = await Geolocator.checkPermission();
  return p == LocationPermission.deniedForever;
}

/// Posizione attuale per il portale: { lat, lng, precisione }. Chiede il permesso se serve.
Future<Json> posizioneAttuale() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw PermessoNegato('Attiva la localizzazione del telefono per completare la sfida.');
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    throw PermessoNegato('Per completare la sfida serve la posizione: sbloccala nelle impostazioni dell\'app.');
  }
  // su Android il GPS del telefono, senza i servizi di Google (che chiederebbero ogni volta di attivare la loro precisione)
  final impostazioni = Platform.isAndroid
      ? AndroidSettings(accuracy: LocationAccuracy.high, forceLocationManager: true, timeLimit: const Duration(seconds: 15))
      : const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15));
  Position? x;
  try {
    x = await Geolocator.getCurrentPosition(locationSettings: impostazioni);
  } on TimeoutException {
    // al chiuso il GPS puo' non rispondere: va bene l'ultima posizione nota
    x = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
  }
  if (x == null) {
    throw PermessoNegato('Posizione non disponibile: spostati vicino a una finestra o all\'aperto e riprova.');
  }
  return {'lat': x.latitude, 'lng': x.longitude, 'precisione': x.accuracy};
}

/// Foto scattata in quel momento con la fotocamera (mai dalla galleria); null se si rinuncia.
Future<List<int>?> scattaFoto() async {
  try {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    return f == null ? null : await f.readAsBytes();
  } catch (_) {
    throw PermessoNegato('Per scattare la foto serve la fotocamera: sbloccala nelle impostazioni dell\'app.');
  }
}

Future<void> apriImpostazioni() => Geolocator.openAppSettings();

/// Lettore di QR a tutto schermo: restituisce il testo del primo QR inquadrato.
Future<String?> leggiQr(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _LettoreQr(), fullscreenDialog: true));

class _LettoreQr extends StatefulWidget {
  const _LettoreQr();
  @override
  State<_LettoreQr> createState() => _LettoreQrState();
}

class _LettoreQrState extends State<_LettoreQr> {
  final _controllo = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _fatto = false;

  @override
  void dispose() {
    _controllo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Inquadra il QR'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Stack(children: [
        MobileScanner(
          controller: _controllo,
          onDetect: (c) {
            final v = c.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (v == null || _fatto) return;
            _fatto = true;
            Navigator.of(context).pop(v);
          },
          errorBuilder: (context, e) => AvvisoPermessi(
            testo: e.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'Per inquadrare i QR serve la fotocamera: sbloccala nelle impostazioni dell\'app.'
                : 'La fotocamera non è disponibile.',
          ),
        ),
        // il riquadro dove mettere il QR
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ]),
    );
  }
}

/// Avviso con il pulsante per aprire le impostazioni dell'app (permessi negati).
class AvvisoPermessi extends StatelessWidget {
  final String testo;
  const AvvisoPermessi({super.key, required this.testo});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(Icons.lock_outline, color: t.colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(testo, style: TextStyle(color: t.colorScheme.onTertiaryContainer, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(onPressed: apriImpostazioni, child: const Text('Apri le impostazioni')),
        ),
      ]),
    );
  }
}

/// Esegue un'azione del gioco mostrando gli errori in una barra in basso; restituisce il risultato o null.
Future<T?> prova<T>(BuildContext context, Future<T> Function() fn) async {
  final avvisi = ScaffoldMessenger.of(context);
  try {
    return await fn();
  } catch (e) {
    avvisi.showSnackBar(SnackBar(content: Text(e is ApiException || e is PermessoNegato ? e.toString() : 'Qualcosa è andato storto. Riprova.')));
    return null;
  }
}
