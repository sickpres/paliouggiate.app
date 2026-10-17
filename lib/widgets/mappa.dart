import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import 'comuni.dart';

// Mappa dei rioni: le stesse zone ed etichette del portale pubblico (index.html del repository paliouggiate,
// viewBox "30 235 850 660"). I colori arrivano dal portale con i rioni.
const _vista = Rect.fromLTWH(30, 235, 850, 660);

class _Zona {
  final String nome;
  final List<Offset> punti;
  final Offset etichetta;
  final double carattere;
  final double gradi;
  final String testo;
  const _Zona(this.nome, this.punti, this.etichetta, this.carattere, this.gradi, [String? testo]) : testo = testo ?? nome;

  Path get path => Path()..addPolygon(punti, true);
}

List<Offset> _p(String s) => [
      for (final c in s.split(' '))
        Offset(double.parse(c.split(',')[0]), double.parse(c.split(',')[1]))
    ];

final _zone = <_Zona>[
  _Zona('Somoca', _p('300,262 330,262 395,322 430,362 445,395 445,440 415,505 355,545 330,538 290,540 250,572 165,570 150,520 135,432 175,385 215,340 260,290'),
      const Offset(292, 440), 46, -12),
  _Zona('Brughiere', _p('135,432 150,520 165,570 250,572 236,605 238,632 170,655 175,720 190,800 205,860 200,878 180,845 150,790 110,740 75,700 80,660 65,610 70,560 45,530 55,505 90,480 95,450'),
      const Offset(128, 622), 27, -68),
  _Zona('Uggiate Centro', _p('250,572 290,540 330,538 355,545 388,583 360,610 335,640 238,632 236,605'),
      const Offset(314, 591), 27, -4, 'Uggiate\nCentro'),
  _Zona('Pastura', _p('170,655 238,632 335,640 355,675 300,715 285,750 300,790 275,820 270,835 215,865 205,860 190,800 175,720'),
      const Offset(243, 712), 24, -62),
  _Zona('Trevano', _p('445,440 490,470 585,532 540,620 500,678 455,688 335,640 360,610 388,583 355,545 415,505'),
      const Offset(462, 566), 30, 20),
  _Zona('Lampona', _p('445,385 495,368 525,368 640,482 610,535 585,532 490,470 445,440'),
      const Offset(540, 432), 27, 43),
  _Zona('Ronago Centro', _p('525,368 555,305 590,285 650,275 690,250 720,250 752,290 750,318 735,420 690,470 640,482'),
      const Offset(640, 372), 31, 14, 'Ronago\nCentro'),
  _Zona('Mulini', _p('752,318 790,320 838,330 858,375 830,405 800,470 760,560 700,640 650,700 580,750 530,765 515,820 495,840 470,790 440,745 455,688 500,678 540,620 585,532 610,535 640,482 690,470 735,420 750,318'),
      const Offset(642, 590), 44, -50),
];

class _Dati {
  final List<Rione> rioni;
  final ClassificaDettaglio classifica;
  final List<AnnoArchivio> archivio;
  _Dati(this.rioni, this.classifica, this.archivio);
}

/// Mappa cliccabile dei rioni con la scheda del rione scelto.
class MappaRioni extends StatefulWidget {
  const MappaRioni({super.key});

  @override
  State<MappaRioni> createState() => _MappaRioniState();
}

class _MappaRioniState extends State<MappaRioni> {
  late final Future<_Dati> _dati = () async {
    final r = await Future.wait([rioniInCache(), Api.instance.classifica(), Api.instance.archivio()]);
    return _Dati(r[0] as List<Rione>, r[1] as ClassificaDettaglio, r[2] as List<AnnoArchivio>);
  }();
  // solo per le schermate di prova nel simulatore: --dart-define=PROVA_MAPPA=Somoca
  String? _scelto = const String.fromEnvironment('PROVA_MAPPA').isEmpty ? null : const String.fromEnvironment('PROVA_MAPPA');

  void _tocca(Offset locale, Size dim) {
    final s = dim.width / _vista.width;
    final p = Offset(locale.dx / s + _vista.left, locale.dy / s + _vista.top);
    String? nome;
    for (final z in _zone) {
      if (z.path.contains(p)) nome = z.nome;
    }
    setState(() => _scelto = nome == null || nome == _scelto ? null : nome);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return FutureBuilder<_Dati>(
      future: _dati,
      builder: (context, s) {
        // senza dati la mappa resta grigia: e' un di piu' della Home
        final d = s.data;
        final rioni = d?.rioni ?? const <Rione>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AspectRatio(
                aspectRatio: _vista.width / _vista.height,
                child: LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    onTapUp: (e) => _tocca(e.localPosition, c.biggest),
                    child: Semantics(
                      label: 'Mappa dei rioni di Uggiate con Ronago',
                      child: CustomPaint(size: c.biggest, painter: _Pittore(rioni, _scelto)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_scelto == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('Tocca un rione sulla mappa per vederne i dettagli.',
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            )
          else if (d != null)
            _Scheda(_scelto!, d),
        ]);
      },
    );
  }
}

bool _chiaro(Color c) => 0.299 * (c.r * 255) + 0.587 * (c.g * 255) + 0.114 * (c.b * 255) > 160;

class _Pittore extends CustomPainter {
  final List<Rione> rioni;
  final String? scelto;
  _Pittore(this.rioni, this.scelto);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _vista.width;
    canvas.save();
    canvas.scale(s);
    canvas.translate(-_vista.left, -_vista.top);
    final bordo = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    for (final z in _zone) {
      final r = rionePerNome(rioni, z.nome);
      var colore = r == null ? const Color(0xFF999999) : coloreHex(r.colore, const Color(0xFF999999));
      if (z.nome == scelto) colore = Color.lerp(colore, Colors.white, 0.12)!;
      canvas.drawPath(z.path, Paint()..color = colore);
      canvas.drawPath(z.path, bordo);
    }
    // rione scelto: bordo bianco spesso con ombra, come sul portale
    if (scelto != null) {
      final z = _zone.firstWhere((x) => x.nome == scelto);
      canvas.drawPath(z.path, Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black54
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawPath(z.path, Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round);
    }
    for (final z in _zone) {
      final r = rionePerNome(rioni, z.nome);
      final scuro = r != null && _chiaro(coloreHex(r.colore, const Color(0xFF999999)));
      _etichetta(canvas, z, scuro);
    }
    canvas.restore();
  }

  void _etichetta(Canvas canvas, _Zona z, bool scuro) {
    TextPainter pittore(Paint p) => TextPainter(
          text: TextSpan(
            text: z.testo,
            style: TextStyle(fontSize: z.carattere, fontWeight: FontWeight.w700, height: 1.1, foreground: p),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
    final contorno = pittore(Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = scuro ? Colors.white60 : Colors.black38);
    final pieno = pittore(Paint()..color = scuro ? const Color(0xFF222222) : Colors.white);
    canvas.save();
    canvas.translate(z.etichetta.dx, z.etichetta.dy);
    canvas.rotate(z.gradi * math.pi / 180);
    final o = Offset(-pieno.width / 2, -pieno.height / 2);
    contorno.paint(canvas, o);
    pieno.paint(canvas, o);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Pittore old) => old.scelto != scelto || old.rioni != rioni;
}

class _Scheda extends StatelessWidget {
  final String nome;
  final _Dati d;
  const _Scheda(this.nome, this.d);

  Widget _foto(Rione r) => Padding(
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
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = rionePerNome(d.rioni, nome);
    final righe = d.classifica.righe;
    final i = righe.indexWhere((x) => x.nome.toLowerCase() == nome.toLowerCase());
    final voci = <(String, String)>[];
    if (i >= 0) {
      voci.add(('Classifica attuale', '${d.classifica.iniziata ? '${i + 1}° · ' : ''}${righe[i].punti} punti'));
    }
    for (final a in d.archivio) {
      for (final c in a.classifica) {
        if (c.nome.toLowerCase() == nome.toLowerCase()) voci.add(('Palio ${a.anno}', '${c.posizione}° · ${c.punti} punti'));
      }
    }
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
          for (var n = 0; n < voci.length; n++) ...[
            const SizedBox(height: 10),
            Text(voci[n].$1.toUpperCase(),
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
            Text(voci[n].$2, style: t.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            // la foto «simbolo» del rione sotto il punteggio attuale
            if (n == 0 && i >= 0 && r != null && r.haSimbolo) _foto(r),
          ],
          if (i < 0 && r != null && r.haSimbolo) _foto(r),
        ]),
      ),
    );
  }
}
