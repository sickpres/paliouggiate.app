import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

const _canale = MethodChannel('palio/mappa');
String? _chiaveImpostata; // Google Maps accetta la chiave una volta sola per avvio dell'app
// solo per le prove nel simulatore: --dart-define=PROVA_SENZA_STILE=true apre la mappa senza lo stile cloud
const _provaSenzaStile = bool.fromEnvironment('PROVA_SENZA_STILE');

// segnaposto tondo dei rioni, in punti: cerchio bianco con l'anello del colore del rione e lo stemma al centro
const _latoSegno = 40.0;

/// Mappa Google (stile dal portale) con i confini dei rioni e un segnaposto tondo per rione. Il rione scelto si
/// colora di piu' e la mappa lo inquadra; un tocco su un rione o sul suo segnaposto lo sceglie, uno fuori lo toglie.
/// Le dita muovono la mappa anche dentro una pagina che scorre.
class MappaRioniGoogle extends StatefulWidget {
  final String? scelto;
  final ValueChanged<String?> onScegli;
  const MappaRioniGoogle({super.key, required this.scelto, required this.onScegli});

  @override
  State<MappaRioniGoogle> createState() => _MappaRioniGoogleState();
}

class _MappaRioniGoogleState extends State<MappaRioniGoogle> {
  late Future<ConfigMappa> _config = _carica();
  ConfigMappa? _c;
  final _segni = <int, BitmapDescriptor>{};
  GoogleMapController? _mappa;
  bool _inquadrata = false;
  Set<int>? _visibili; // segnaposto che non si sovrappongono allo zoom attuale

  Future<ConfigMappa> _carica() async {
    final c = await Api.instance.mappa();
    if (c.chiaveIos.isNotEmpty && _chiaveImpostata == null) {
      await _canale.invokeMethod('impostaChiave', c.chiaveIos);
      _chiaveImpostata = c.chiaveIos;
    }
    _c = c;
    _caricaSegni(c);
    return c;
  }

  // segnaposto disegnati una volta per rione: prima senza stemma, poi con lo stemma appena arriva
  Future<void> _caricaSegni(ConfigMappa c) async {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    for (final r in c.rioni.where((x) => x.anelli.isNotEmpty)) {
      ui.Image? stemma;
      if (r.rione.haLogo) {
        try {
          final risposta = await http.get(Uri.parse(Api.instance.logoRione(r.rione)));
          if (risposta.statusCode == 200) {
            final codec = await ui.instantiateImageCodec(risposta.bodyBytes, targetWidth: (26 * dpr).round());
            stemma = (await codec.getNextFrame()).image;
          }
        } catch (_) {
          // senza stemma il segnaposto resta un cerchio del colore del rione
        }
      }
      final segno = await _disegnaSegno(coloreHex(r.rione.colore), stemma, dpr);
      if (segno == null) continue;
      _segni[r.rione.id] = segno;
      if (mounted) setState(() {});
    }
  }

  static Future<BitmapDescriptor?> _disegnaSegno(Color colore, ui.Image? stemma, double dpr) async {
    final lato = _latoSegno * dpr;
    final registro = ui.PictureRecorder();
    final tela = Canvas(registro);
    final centro = Offset(lato / 2, lato / 2);
    final raggio = lato / 2 - 2 * dpr;
    tela.drawCircle(centro + Offset(0, 1.5 * dpr), raggio, Paint()
      ..color = Colors.black26
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * dpr));
    if (stemma == null) {
      tela.drawCircle(centro, raggio, Paint()..color = colore);
      tela.drawCircle(centro, raggio, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * dpr
        ..color = Colors.white);
    } else {
      tela.drawCircle(centro, raggio, Paint()..color = Colors.white);
      tela.drawCircle(centro, raggio - 1.75 * dpr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * dpr
        ..color = colore);
      final w = stemma.width.toDouble(), h = stemma.height.toDouble();
      final scala = math.min(24 * dpr / w, 24 * dpr / h);
      final dest = Rect.fromCenter(center: centro, width: w * scala, height: h * scala);
      tela.drawImageRect(stemma, Rect.fromLTWH(0, 0, w, h), dest, Paint()..filterQuality = FilterQuality.high);
    }
    final img = await registro.endRecording().toImage(lato.round(), lato.round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return null;
    return BitmapDescriptor.bytes(png.buffer.asUint8List(), width: _latoSegno);
  }

  @override
  void didUpdateWidget(MappaRioniGoogle vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.scelto != widget.scelto) _inquadra();
  }

  // inquadra il rione scelto, oppure tutti i rioni
  void _inquadra() {
    final c = _c;
    if (c == null || _mappa == null) return;
    final r = widget.scelto == null ? null : c.rioni.where((x) => x.rione.nome == widget.scelto).firstOrNull;
    final limiti = r == null ? _limiti(c.rioni) : _limiti([r]);
    if (limiti != null) _mappa!.animateCamera(CameraUpdate.newLatLngBounds(limiti, r == null ? 28 : 48));
  }

  static LatLng _ll((double, double) p) => LatLng(p.$1, p.$2);

  // punto dove mettere il segnaposto: il baricentro dell'anello piu' grande
  static LatLng _centro(List<(double, double)> a) {
    double x = 0, y = 0, area = 0;
    for (var i = 0; i < a.length; i++) {
      final p = a[i], q = a[(i + 1) % a.length];
      final k = p.$2 * q.$1 - q.$2 * p.$1;
      area += k;
      x += (p.$2 + q.$2) * k;
      y += (p.$1 + q.$1) * k;
    }
    if (area.abs() < 1e-12) return _ll(a.first);
    return LatLng(y / (3 * area), x / (3 * area));
  }

  // Segnaposto da mostrare a uno zoom: si proiettano sullo schermo (Web Mercator, tile da 256 punti); se anche solo
  // due si toccano spariscono tutti, e tornano tutti insieme quando c'e' spazio.
  static Set<int> _segniVisibili(ConfigMappa c, double zoom) {
    final scala = 256 * math.pow(2, zoom).toDouble();
    Offset schermo(LatLng p) {
      final s = math.sin(p.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
      return Offset((p.longitude + 180) / 360 * scala, (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scala);
    }
    final rioni = c.rioni.where((r) => r.anelli.isNotEmpty).toList();
    final punti = [for (final r in rioni) schermo(_centro(r.anelli.reduce((a, b) => a.length >= b.length ? a : b)))];
    for (var i = 0; i < punti.length; i++) {
      for (var j = i + 1; j < punti.length; j++) {
        if ((punti[i] - punti[j]).distance < _latoSegno + 2) return <int>{};
      }
    }
    return {for (final r in rioni) r.rione.id};
  }

  static LatLngBounds? _limiti(List<RioneMappa> rioni) {
    final punti = [for (final r in rioni) for (final a in r.anelli) ...a];
    if (punti.isEmpty) return null;
    final lat = punti.map((p) => p.$1), lng = punti.map((p) => p.$2);
    return LatLngBounds(southwest: LatLng(lat.reduce(math.min), lng.reduce(math.min)), northeast: LatLng(lat.reduce(math.max), lng.reduce(math.max)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConfigMappa>(
      future: _config,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Messaggio(
              icona: Icons.cloud_off,
              titolo: 'Impossibile caricare la mappa',
              azione: FilledButton.tonalIcon(
                onPressed: () => setState(() => _config = _carica()),
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final c = s.data!;
        if (c.chiaveIos.isEmpty) {
          return const Center(
            child: Messaggio(
              icona: Icons.map_outlined,
              titolo: 'Mappa non ancora disponibile',
              testo: 'La mappa comparirà appena sarà configurata nel portale del Palio.',
            ),
          );
        }
        return _mappaConRioni(c);
      },
    );
  }

  Widget _mappaConRioni(ConfigMappa c) {
    final limiti = _limiti(c.rioni);
    final poligoni = <Polygon>{};
    final segni = <Marker>{};
    final visibili = _visibili ??= _segniVisibili(c, 13);
    for (final r in c.rioni) {
      final col = coloreHex(r.rione.colore);
      final scelto = widget.scelto == r.rione.nome;
      // con un rione scelto gli altri si schiariscono
      final alfa = scelto ? 0.45 : (widget.scelto == null ? 0.22 : 0.10);
      for (var i = 0; i < r.anelli.length; i++) {
        poligoni.add(Polygon(
          polygonId: PolygonId('${r.rione.id}-$i'),
          points: [for (final p in r.anelli[i]) _ll(p)],
          fillColor: col.withValues(alpha: alfa),
          strokeColor: col,
          strokeWidth: scelto ? 4 : 2,
          consumeTapEvents: true,
          onTap: () => widget.onScegli(scelto ? null : r.rione.nome),
        ));
      }
      if (r.anelli.isNotEmpty) {
        final grande = r.anelli.reduce((a, b) => a.length >= b.length ? a : b);
        segni.add(Marker(
          markerId: MarkerId('${r.rione.id}'),
          position: _centro(grande),
          icon: _segni[r.rione.id] ?? BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(col).hue),
          anchor: const Offset(0.5, 0.5),
          visible: scelto || visibili.contains(r.rione.id),
          zIndexInt: scelto ? 1 : 0,
          onTap: () => widget.onScegli(r.rione.nome),
        ));
      }
    }
    return GoogleMap(
      mapId: c.stile.isEmpty || _provaSenzaStile ? null : c.stile,
      initialCameraPosition: CameraPosition(
          target: limiti == null
              ? const LatLng(45.82, 8.96)
              : LatLng((limiti.southwest.latitude + limiti.northeast.latitude) / 2, (limiti.southwest.longitude + limiti.northeast.longitude) / 2),
          zoom: 13),
      polygons: poligoni,
      markers: segni,
      // la mappa prende per se' le dita anche dentro la pagina che scorre
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (m) => _mappa = m,
      // allontanandosi i segnaposto che si toccano spariscono, e tornano quando c'e' spazio
      onCameraMove: (pos) {
        final v = _segniVisibili(c, pos.zoom);
        if (!setEquals(v, _visibili)) setState(() => _visibili = v);
      },
      // la prima volta che la mappa e' ferma (prima non conosce ancora le sue misure) si inquadrano i rioni
      onCameraIdle: () {
        if (_inquadrata) return;
        _inquadrata = true;
        _inquadra();
      },
      onTap: (_) => widget.onScegli(null),
    );
  }
}
