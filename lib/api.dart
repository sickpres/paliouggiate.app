import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

const baseUrl = 'https://palio.comune.uggiateconronago.co.it';

class ApiException implements Exception {
  final int status; // 0 = nessuna risposta dal server
  final String message;
  ApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// Client delle API pubbliche del portale: solo lettura, nessun accesso.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _timeout = Duration(seconds: 20);

  final _client = http.Client();

  String url(String path) => '$baseUrl/api/$path';

  Future<dynamic> _get(String path) async {
    final http.Response r;
    try {
      r = await _client.get(Uri.parse(url(path)), headers: {'Accept': 'application/json'}).timeout(_timeout);
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
      final msg = data is Map && data['errore'] is String ? data['errore'] as String : 'Errore del server (${r.statusCode})';
      throw ApiException(r.statusCode, msg);
    }
    return data;
  }

  Map<String, dynamic> _mappa(dynamic d) => Map<String, dynamic>.from(d as Map);
  List<Map<String, dynamic>> _lista(dynamic d) => [for (final x in (d as List? ?? const [])) _mappa(x)];

  Future<Edizione> edizione() async => Edizione.fromJson(_mappa(await _get('config')));
  Future<List<Rione>> rioni() async => _lista(await _get('rioni')).map(Rione.fromJson).toList();
  Future<List<Voce>> calendario() async => _lista(await _get('calendario')).map(Voce.fromJson).toList();
  Future<ClassificaDettaglio> classifica() async => ClassificaDettaglio.fromJson(_mappa(await _get('classifica/dettaglio')));
  Future<List<AnnoArchivio>> archivio() async => _lista(await _get('archivio')).map(AnnoArchivio.fromJson).toList();
  Future<List<Gioco>> giochi() async => _lista(await _get('giochi')).map(Gioco.fromJson).toList();
  Future<CalendarioPartite> partite(String tipo) async => CalendarioPartite.fromJson(_mappa(await _get('partite/$tipo')));
  /// null se il portale non ha ancora una telecronaca
  Future<Telecronaca?> telecronaca() async {
    final t = Telecronaca.fromJson(_mappa(await _get('telecronaca')));
    return t.testo.isEmpty ? null : t;
  }

  Future<List<Sponsor>> sponsor() async => _lista(await _get('sponsor')).map(Sponsor.fromJson).toList();

  String logoRione(Rione r) => '${url('rioni/${r.id}/logo')}?v=${r.logoVersione}';
  String logoSponsor(Sponsor s) => url('sponsor/${s.id}/logo');
}
