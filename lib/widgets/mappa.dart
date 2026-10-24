import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import 'comuni.dart';

/// Scheda di un rione: stemma, nome, descrizione, capo rione, «Unisciti a noi» (gruppo WhatsApp) e la foto «simbolo» se c'e'.
class SchedaRione extends StatelessWidget {
  final String nome;
  final List<Rione> rioni;
  const SchedaRione(this.nome, this.rioni, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = rionePerNome(rioni, nome);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SegnoRione(rione: r, colore: r?.colore ?? '', lato: 48),
            const SizedBox(width: 12),
            Expanded(child: Text(nome, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          if (r != null && r.descrizione.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(r.descrizione)),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Capo rione: '),
            TextSpan(
                text: r != null && r.capoRione.isNotEmpty ? r.capoRione : 'da definire',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ])),
          if (r != null && r.whatsapp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => unisciti(context, r),
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                  label: const Text('Unisciti a noi'),
                ),
              ),
            ),
          if (r != null && r.haSimbolo)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    Api.instance.simboloRione(r),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, figlio, avanzamento) =>
                        avanzamento == null ? figlio : ColoredBox(color: coloreHex(r.colore).withValues(alpha: 0.15)),
                    errorBuilder: (context, e, s) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

const _testoUnisciti = 'Vorrei partecipare al Palio';

/// «Unisciti a noi»: apre il gruppo WhatsApp del rione. Un link a un numero (wa.me) porta gia' il messaggio;
/// i link d'invito ai gruppi non accettano un testo: si copia negli appunti, da incollare nel gruppo.
Future<void> unisciti(BuildContext context, Rione r) async {
  final uri = Uri.tryParse(r.whatsapp);
  if (uri == null) return;
  final numero = uri.host == 'wa.me' || uri.host == 'api.whatsapp.com';
  final dove = numero ? uri.replace(queryParameters: {...uri.queryParameters, 'text': _testoUnisciti}) : uri;
  final messaggi = ScaffoldMessenger.of(context);
  if (!numero) {
    await Clipboard.setData(const ClipboardData(text: _testoUnisciti));
    messaggi.showSnackBar(const SnackBar(content: Text('Messaggio copiato: incollalo nel gruppo («$_testoUnisciti»)')));
  }
  if (!await launchUrl(dove, mode: LaunchMode.externalApplication)) {
    messaggi.showSnackBar(const SnackBar(content: Text('Non riesco ad aprire WhatsApp')));
  }
}

// ---------- mappa disegnata: assets/mappa_rioni.webp (1129 x 980, ritagliata sopra e sotto i rioni) ----------
const _larghezza = 1129.0, _altezza = 980.0;

class _Zona {
  final String nome;
  final Offset stemma; // centro dello stemma nel disegno
  final List<Offset> confine; // contorno approssimato, per capire quale rione si tocca
  const _Zona(this.nome, this.stemma, this.confine);
}

List<Offset> _p(String s) => [
      for (final c in s.split(' ')) Offset(double.parse(c.split(',')[0]), double.parse(c.split(',')[1]))
    ];

// Confini: quelli della vecchia mappa del portale portati sul disegno (trasformazione affine stimata sugli stemmi,
// scarto massimo una ventina di pixel). Bastano per il tocco; per evidenziare il rione si usa lo stemma.
final _zone = <_Zona>[
  _Zona('Somoca', const Offset(375, 295),
      _p('381,39 419,44 505,142 551,206 572,257 574,322 538,412 463,460 431,446 380,442 330,482 221,465 200,390 177,259 226,197 276,138 331,73')),
  _Zona('Brughiere', const Offset(175, 533),
      _p('177,259 200,390 221,465 330,482 313,528 317,568 231,590 240,686 263,805 284,895 279,920 252,869 211,784 158,704 112,640 116,582 95,507 100,435 66,387 78,352 122,322 127,279')),
  _Zona('Uggiate Centro', const Offset(408, 500), _p('330,482 380,442 431,446 463,460 507,521 472,556 441,596 317,568 313,528')),
  _Zona('Pastura', const Offset(348, 720),
      _p('231,590 317,568 441,596 468,650 400,699 382,748 403,808 372,848 366,869 297,904 284,895 263,805 240,686')),
  _Zona('Trevano', const Offset(598, 530), _p('574,322 632,374 756,480 702,600 654,678 596,685 441,596 472,556 507,521 463,460 538,412')),
  _Zona('Lampona', const Offset(686, 340), _p('571,242 634,226 673,231 824,416 788,488 756,480 632,374 574,322')),
  _Zona('Ronago Centro', const Offset(848, 240),
      _p('673,231 708,144 752,120 828,116 878,86 917,91 959,155 958,195 943,341 888,407 824,416')),
  _Zona('Mulini', const Offset(830, 558),
      _p('960,195 1009,205 1071,227 1098,296 1064,335 1028,425 981,549 907,656 846,735 759,796 696,810 679,888 654,914 620,837 580,766 596,685 654,678 702,600 756,480 788,488 824,416 888,407 943,341 958,195')),
];

/// Mappa disegnata dei rioni: un tocco su un rione lo sceglie (su quello gia' scelto o fuori dai rioni lo toglie).
/// Il rione scelto ha un anello del suo colore attorno allo stemma.
class MappaDisegnata extends StatelessWidget {
  final List<Rione> rioni;
  final String? scelto;
  final ValueChanged<String?> onScegli;
  const MappaDisegnata({super.key, required this.rioni, required this.scelto, required this.onScegli});

  void _tocca(Offset locale, Size dim) {
    final p = Offset(locale.dx * _larghezza / dim.width, locale.dy * _altezza / dim.height);
    String? nome;
    // prima lo stemma piu' vicino (se il tocco e' sopra uno stemma), poi il confine che contiene il punto
    for (final z in _zone) {
      if ((z.stemma - p).distance < 60) nome = z.nome;
    }
    if (nome == null) {
      for (final z in _zone) {
        if ((Path()..addPolygon(z.confine, true)).contains(p)) nome = z.nome;
      }
    }
    onScegli(nome == null || nome == scelto ? null : nome);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _larghezza / _altezza,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          onTapUp: (e) => _tocca(e.localPosition, c.biggest),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/mappa_rioni.webp',
                fit: BoxFit.fill, cacheWidth: (c.maxWidth * MediaQuery.devicePixelRatioOf(context)).round(), excludeFromSemantics: true),
            if (scelto != null) CustomPaint(painter: _Anello(_zone.where((z) => z.nome == scelto).firstOrNull, rioni)),
          ]),
        ),
      ),
    );
  }
}

/// Anello attorno allo stemma del rione scelto: bianco con ombra, poi il colore del rione.
class _Anello extends CustomPainter {
  final _Zona? zona;
  final List<Rione> rioni;
  _Anello(this.zona, this.rioni);

  @override
  void paint(Canvas canvas, Size size) {
    final z = zona;
    if (z == null) return;
    final s = size.width / _larghezza;
    final centro = Offset(z.stemma.dx * s, z.stemma.dy * s);
    final raggio = 70 * s;
    final colore = coloreHex(rionePerNome(rioni, z.nome)?.colore ?? '', Colors.white);
    canvas.drawCircle(centro, raggio, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(6, 14 * s)
      ..color = Colors.black38
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(centro, raggio, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(5, 12 * s)
      ..color = Colors.white);
    canvas.drawCircle(centro, raggio, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, 5 * s)
      ..color = colore);
  }

  @override
  bool shouldRepaint(_Anello old) => old.zona != zona || old.rioni != rioni;
}
