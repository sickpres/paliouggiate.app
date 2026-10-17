import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
// --dart-define=PROVA_ZOOM=11.5 porta la mappa a quello zoom dopo l'inquadratura
const _provaZoom = String.fromEnvironment('PROVA_ZOOM');

/// Mappa a tutta pagina (Google Maps, stile dal portale) con i confini dei rioni e i loro stemmi.
class PaginaMappa extends StatefulWidget {
  const PaginaMappa({super.key});

  @override
  State<PaginaMappa> createState() => _PaginaMappaState();
}

class _PaginaMappaState extends State<PaginaMappa> {
  late Future<ConfigMappa> _config = _carica();
  final _stemmi = <int, BitmapDescriptor>{};
  GoogleMapController? _mappa;
  bool _inquadrata = false;
  Set<int>? _visibili; // stemmi che non si sovrappongono allo zoom attuale
  String? _scelto;

  Future<ConfigMappa> _carica() async {
    final c = await Api.instance.mappa();
    if (c.chiaveIos.isNotEmpty && _chiaveImpostata == null) {
      await _canale.invokeMethod('impostaChiave', c.chiaveIos);
      _chiaveImpostata = c.chiaveIos;
    }
    _caricaStemmi(c);
    return c;
  }

  // stemmi dei rioni come segnaposto, rimpiccioliti e convertiti in PNG
  Future<void> _caricaStemmi(ConfigMappa c) async {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    for (final r in c.rioni.where((x) => x.rione.haLogo && x.anelli.isNotEmpty)) {
      try {
        final risposta = await http.get(Uri.parse(Api.instance.logoRione(r.rione)));
        if (risposta.statusCode != 200) continue;
        final codec = await ui.instantiateImageCodec(risposta.bodyBytes, targetWidth: (40 * dpr).round());
        final img = (await codec.getNextFrame()).image;
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) continue;
        _stemmi[r.rione.id] = BitmapDescriptor.bytes(png.buffer.asUint8List(), width: 40);
        if (mounted) setState(() {});
      } catch (_) {
        // senza stemma il rione resta solo colorato
      }
    }
  }

  static LatLng _ll((double, double) p) => LatLng(p.$1, p.$2);

  // punto dove mettere lo stemma: il baricentro dell'anello piu' grande
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

  static double _area(List<(double, double)> a) {
    double s = 0;
    for (var i = 0; i < a.length; i++) {
      final p = a[i], q = a[(i + 1) % a.length];
      s += p.$2 * q.$1 - q.$2 * p.$1;
    }
    return s.abs() / 2;
  }

  // Stemmi da mostrare a uno zoom: si proiettano sullo schermo (Web Mercator, tile da 256 punti) e, se due si
  // toccano, resta quello del rione piu' grande. Lo stemma e' largo 40 punti; 4 di margine.
  static Set<int> _stemmiVisibili(ConfigMappa c, double zoom) {
    final scala = 256 * math.pow(2, zoom).toDouble();
    Offset schermo(LatLng p) {
      final s = math.sin(p.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
      return Offset((p.longitude + 180) / 360 * scala, (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scala);
    }
    final rioni = c.rioni.where((r) => r.anelli.isNotEmpty).toList()
      ..sort((a, b) => _area(b.anelli.reduce((x, y) => x.length >= y.length ? x : y)).compareTo(_area(a.anelli.reduce((x, y) => x.length >= y.length ? x : y))));
    final tenuti = <Offset>[];
    final out = <int>{};
    for (final r in rioni) {
      final p = schermo(_centro(r.anelli.reduce((a, b) => a.length >= b.length ? a : b)));
      if (tenuti.every((q) => (q - p).distance >= 44)) {
        tenuti.add(p);
        out.add(r.rione.id);
      }
    }
    return out;
  }

  static LatLngBounds? _limiti(ConfigMappa c) {
    final punti = [for (final r in c.rioni) for (final a in r.anelli) ...a];
    if (punti.isEmpty) return null;
    final lat = punti.map((p) => p.$1), lng = punti.map((p) => p.$2);
    return LatLngBounds(southwest: LatLng(lat.reduce(math.min), lng.reduce(math.min)), northeast: LatLng(lat.reduce(math.max), lng.reduce(math.max)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mappa dei rioni')),
      body: FutureBuilder<ConfigMappa>(
        future: _config,
        builder: (context, s) {
          if (s.hasError) {
            return Messaggio(
              icona: Icons.cloud_off,
              titolo: 'Impossibile caricare la mappa',
              testo: s.error is ApiException ? s.error.toString() : null,
              azione: FilledButton.tonalIcon(
                onPressed: () => setState(() => _config = _carica()),
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            );
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final c = s.data!;
          if (c.chiaveIos.isEmpty) {
            return const Messaggio(
              icona: Icons.map_outlined,
              titolo: 'Mappa non ancora disponibile',
              testo: 'La mappa comparirà appena sarà configurata nel portale del Palio.',
            );
          }
          return _mappaConRioni(context, c);
        },
      ),
    );
  }

  Widget _mappaConRioni(BuildContext context, ConfigMappa c) {
    final t = Theme.of(context);
    final limiti = _limiti(c);
    final poligoni = <Polygon>{};
    final segni = <Marker>{};
    final visibili = _visibili ??= _stemmiVisibili(c, 13.5);
    for (final r in c.rioni) {
      final col = coloreHex(r.rione.colore);
      final scelto = _scelto == r.rione.nome;
      for (var i = 0; i < r.anelli.length; i++) {
        poligoni.add(Polygon(
          polygonId: PolygonId('${r.rione.id}-$i'),
          points: [for (final p in r.anelli[i]) _ll(p)],
          fillColor: col.withValues(alpha: scelto ? 0.55 : 0.35),
          strokeColor: col,
          strokeWidth: scelto ? 4 : 2,
          consumeTapEvents: true,
          onTap: () => setState(() => _scelto = scelto ? null : r.rione.nome),
        ));
      }
      if (r.anelli.isNotEmpty) {
        final grande = r.anelli.reduce((a, b) => a.length >= b.length ? a : b);
        segni.add(Marker(
          markerId: MarkerId('${r.rione.id}'),
          position: _centro(grande),
          icon: _stemmi[r.rione.id] ?? BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(col).hue),
          anchor: const Offset(0.5, 0.5),
          visible: visibili.contains(r.rione.id),
          infoWindow: InfoWindow(title: r.rione.nome),
          onTap: () => setState(() => _scelto = r.rione.nome),
        ));
      }
    }
    return Stack(children: [
      GoogleMap(
        mapId: c.stile.isEmpty || _provaSenzaStile ? null : c.stile,
        initialCameraPosition: CameraPosition(
            target: limiti == null
                ? const LatLng(45.82, 8.96)
                : LatLng((limiti.southwest.latitude + limiti.northeast.latitude) / 2, (limiti.southwest.longitude + limiti.northeast.longitude) / 2),
            zoom: 13.5),
        polygons: poligoni,
        markers: segni,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        onMapCreated: (m) => _mappa = m,
        // allontanandosi gli stemmi che si toccano spariscono, e tornano quando c'e' spazio
        onCameraMove: (pos) {
          final v = _stemmiVisibili(c, pos.zoom);
          if (!setEquals(v, _visibili)) setState(() => _visibili = v);
        },
        // tutti i rioni nello schermo: la prima volta che la mappa e' ferma (prima non conosce ancora le sue misure)
        onCameraIdle: () {
          if (_inquadrata || limiti == null || _mappa == null) return;
          _inquadrata = true;
          _mappa!.animateCamera(_provaZoom.isEmpty
              ? CameraUpdate.newLatLngBounds(limiti, 24)
              : CameraUpdate.newLatLngZoom(
                  LatLng((limiti.southwest.latitude + limiti.northeast.latitude) / 2, (limiti.southwest.longitude + limiti.northeast.longitude) / 2),
                  double.parse(_provaZoom)));
        },
        onTap: (_) => setState(() => _scelto = null),
      ),
      if (c.approssimati)
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Center(
            child: Material(
              color: t.colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text('Confini dei rioni indicativi', style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      if (_scelto != null)
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: SegnoRione(rione: rionePerNome([for (final r in c.rioni) r.rione], _scelto!), colore: '', lato: 40),
              title: Text(_scelto!, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _scelto = null)),
            ),
          ),
        ),
    ]);
  }
}
