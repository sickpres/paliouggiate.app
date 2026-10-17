import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const baseUrl = 'https://palio.comune.uggiateconronago.co.it';

class ApiException implements Exception {
  final int status; // 0 = nessuna risposta dal server
  final String message;
  ApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// Client del portale. Il portale autentica con un cookie `sess` firmato
/// (8 ore, legato alla password): qui lo si conserva e lo si rimanda a mano.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _kCookie = 'sessione';
  static const _timeout = Duration(seconds: 20);

  final _client = http.Client();
  String? _cookie;

  bool get haSessione => _cookie != null;

  Future<void> carica() async {
    final p = await SharedPreferences.getInstance();
    _cookie = p.getString(_kCookie);
  }

  Future<void> _salvaCookie(String? c) async {
    _cookie = (c == null || c.isEmpty) ? null : c;
    final p = await SharedPreferences.getInstance();
    if (_cookie == null) {
      await p.remove(_kCookie);
    } else {
      await p.setString(_kCookie, _cookie!);
    }
  }

  String url(String path) => '$baseUrl/api/$path';

  Future<dynamic> _get(String path) => _invia(http.Request('GET', Uri.parse(url(path))));

  Future<dynamic> _json(String method, String path, Map<String, dynamic> body) {
    final req = http.Request(method, Uri.parse(url(path)))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
    return _invia(req);
  }

  Future<dynamic> _invia(http.Request req) async {
    req.headers['Accept'] = 'application/json';
    if (_cookie != null) req.headers['Cookie'] = 'sess=$_cookie';
    final http.Response r;
    try {
      r = await http.Response.fromStream(await _client.send(req).timeout(_timeout));
    } on TimeoutException {
      throw ApiException(0, 'Il server non risponde. Riprova tra poco.');
    } on SocketException {
      throw ApiException(0, 'Connessione assente. Controlla la rete e riprova.');
    } on http.ClientException {
      throw ApiException(0, 'Connessione non riuscita. Riprova tra poco.');
    }
    final sc = r.headers['set-cookie'];
    if (sc != null) {
      final m = RegExp(r'sess=([^;]*)').firstMatch(sc);
      if (m != null) await _salvaCookie(m.group(1));
    }
    dynamic data;
    try {
      data = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 400) {
      final msg = data is Map && data['errore'] is String ? data['errore'] as String : 'Errore del server (${r.statusCode})';
      throw ApiException(r.statusCode, msg);
    }
    return data;
  }

  Map<String, dynamic> _mappa(dynamic d) => Map<String, dynamic>.from(d as Map);
  List<Map<String, dynamic>> _lista(dynamic d) => [for (final x in (d as List? ?? const [])) _mappa(x)];

  // ---------- dati pubblici ----------
  Future<Edizione> edizione() async => Edizione.fromJson(_mappa(await _get('config')));
  Future<List<Rione>> rioni() async => _lista(await _get('rioni')).map(Rione.fromJson).toList();
  Future<List<Voce>> calendario() async => _lista(await _get('calendario')).map(Voce.fromJson).toList();
  Future<ClassificaDettaglio> classifica() async => ClassificaDettaglio.fromJson(_mappa(await _get('classifica/dettaglio')));
  Future<List<AnnoArchivio>> archivio() async => _lista(await _get('archivio')).map(AnnoArchivio.fromJson).toList();
  Future<List<Gioco>> giochi() async => _lista(await _get('giochi')).map(Gioco.fromJson).toList();
  Future<List<Sponsor>> sponsor() async => _lista(await _get('sponsor')).map(Sponsor.fromJson).toList();

  String logoRione(Rione r) => '${url('rioni/${r.id}/logo')}?v=${r.logoVersione}';
  String logoSponsor(Sponsor s) => url('sponsor/${s.id}/logo');

  // ---------- accesso e profilo ----------
  /// null se non c'e' una sessione valida.
  Future<Sessione?> sessione() async {
    final d = _mappa(await _get('sessione'));
    if (d['admin'] != true) {
      await _salvaCookie(null);
      return null;
    }
    return Sessione.fromJson(d);
  }

  /// Restituisce true se l'utente deve cambiare la password.
  Future<bool> accedi(String utente, String password) async {
    final d = await _json('POST', 'login', {'utente': utente, 'password': password});
    return d is Map && d['cambiaPassword'] == true;
  }

  Future<void> esci() async {
    try {
      await _json('POST', 'logout', {});
    } catch (_) {
      // anche senza rete la sessione locale va chiusa
    }
    await _salvaCookie(null);
  }

  Future<void> cambiaPassword(String vecchia, String nuova) => _json('POST', 'password', {'vecchia': vecchia, 'nuova': nuova});

  Future<Profilo> profilo() async => Profilo.fromJson(_mappa(await _get('profilo')));

  Future<Profilo> salvaProfilo(Profilo p) async =>
      Profilo.fromJson(_mappa(await _json('PUT', 'profilo', {'nome': p.nome, 'cognome': p.cognome, 'telefono': p.telefono})));
}
