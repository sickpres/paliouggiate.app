import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'api_tesoro.dart';

// Sfide del livello 1 («Riscalda i neuroni»): Memory e Puzzle (4 colonne per 5 righe) e Differenze, entro il tempo
// scelto nel pannello. Il tempo lo misura il portale (dall'inizio alla fine della partita); qui c'e' il conto alla rovescia.

class PaginaSfide extends StatelessWidget {
  final Json io;
  final Future<void> Function() aggiorna;
  const PaginaSfide({super.key, required this.io, required this.aggiorna});

  Future<void> _gioca(BuildContext context, String gioco) async {
    final livello = (io['giocatore'] as Json)['livello'] as int;
    if (livello != 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le sfide sono già completate: ora si gioca sulla mappa.')));
      return;
    }
    final partita = await prova(context, () => TesoroApi.instance.iniziaSfida(gioco));
    if (partita == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => switch (gioco) {
              'memory' => PaginaMemory(partita: partita),
              'puzzle' => PaginaPuzzle(partita: partita),
              _ => PaginaDifferenze(partita: partita),
            }));
    await aggiorna();
  }

  @override
  Widget build(BuildContext context) {
    final n = io['neuroni'] as Json;
    final tempi = n['tempi'] as Json;
    String stato(String g) => n[g] == null ? '${tempi[g]} secondi: ce la fai?' : 'Fatto in ${n[g]} secondi';
    return ListView(padding: const EdgeInsets.all(16), children: [
      _Riquadro(titolo: 'Memory', icona: Icons.style, sotto: stato('memory'), fatto: n['memory'] != null, onTap: () => _gioca(context, 'memory')),
      const SizedBox(height: 16),
      _Riquadro(titolo: 'Puzzle', icona: Icons.extension, sotto: stato('puzzle'), fatto: n['puzzle'] != null, onTap: () => _gioca(context, 'puzzle')),
      const SizedBox(height: 16),
      _Riquadro(titolo: 'Differenze', icona: Icons.compare, sotto: stato('differenze'), fatto: n['differenze'] != null, onTap: () => _gioca(context, 'differenze')),
    ]);
  }
}

class _Riquadro extends StatelessWidget {
  final String titolo;
  final IconData icona;
  final String sotto;
  final bool fatto;
  final VoidCallback onTap;
  const _Riquadro({required this.titolo, required this.icona, required this.sotto, required this.fatto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bluNotte,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          height: 170,
          child: Stack(children: [
            Positioned(right: -10, bottom: -20, child: Icon(icona, size: 150, color: Colors.white.withValues(alpha: 0.08))),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titolo, style: const TextStyle(fontFamily: fontTitoli, fontSize: 40, fontWeight: FontWeight.w800, color: oro)),
                const Spacer(),
                Row(children: [
                  if (fatto) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_circle, color: Colors.lightGreenAccent)),
                  Expanded(child: Text(sotto, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
                  const Icon(Icons.play_circle_fill, color: oro, size: 44),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------- conto alla rovescia comune ----------
mixin _ContoAllaRovescia<T extends StatefulWidget> on State<T> {
  late int restano;
  Timer? _timer;
  bool finita = false;

  void avviaTempo(int secondi) {
    restano = secondi;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || finita) return t.cancel();
      setState(() => restano--);
      if (restano <= 0) {
        t.cancel();
        _tempoScaduto();
      }
    });
  }

  Future<void> _tempoScaduto() async {
    finita = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Tempo scaduto'),
        content: const Text('Riprova: la prossima volta andrà meglio!'),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  // il portale conferma (o no) il tempo della partita finita
  Future<void> vinto(String gioco, String partita) async {
    finita = true;
    _timer?.cancel();
    final r = await prova(context, () => TesoroApi.instance.fineSfida(gioco, partita));
    if (!mounted) return;
    final ok = r?['valida'] == true;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ok ? 'Bravo!' : 'Peccato'),
        content: Text(ok ? 'Completato in ${r!['secondi']} secondi.' : 'Il tempo non è valido: riprova.'),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Widget barraTempo(int totale) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(children: [
          LinearProgressIndicator(value: restano / totale, minHeight: 10, borderRadius: BorderRadius.circular(6), color: restano <= 10 ? rosso : oro),
          const SizedBox(height: 8),
          Text('$restano secondi', style: TextStyle(fontFamily: fontTitoli, fontSize: 28, fontWeight: FontWeight.w800, color: restano <= 10 ? rosso : null)),
        ]),
      );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ---------- Differenze: due immagini 4:3 una sopra l'altra; si toccano le differenze, su una delle due ----------
// Le differenze arrivano dal portale come cerchi { x, y, r } in frazioni dell'immagine (r della larghezza).
class PaginaDifferenze extends StatefulWidget {
  final Json partita;
  const PaginaDifferenze({super.key, required this.partita});
  @override
  State<PaginaDifferenze> createState() => _PaginaDifferenzeState();
}

class _PaginaDifferenzeState extends State<PaginaDifferenze> with _ContoAllaRovescia {
  late final List<Json> _differenze;
  final _trovate = <int>{};
  late final int _totale;
  late final List<ImageProvider> _immagini;
  int _caricate = 0;
  Offset? _errore; // ultimo tocco a vuoto (frazioni dell'immagine), mostrato per un attimo
  int? _erroreSu;
  Timer? _via;

  @override
  void initState() {
    super.initState();
    _differenze = [for (final d in widget.partita['differenze'] as List) Map<String, dynamic>.from(d as Map)];
    _totale = (widget.partita['secondi'] as num).toInt();
    restano = _totale;
    _immagini = [for (final i in widget.partita['immagini'] as List) NetworkImage(TesoroApi.instance.indirizzo(i as String))];
    // il tempo parte quando si vedono tutte e due le immagini
    for (final img in _immagini) {
      img.resolve(ImageConfiguration.empty).addListener(ImageStreamListener((_, __) {
        if (!mounted) return;
        setState(() => _caricate++);
        if (_caricate == _immagini.length) avviaTempo(_totale);
      }));
    }
  }

  @override
  void dispose() {
    _via?.cancel();
    super.dispose();
  }

  void _tocca(int su, Offset f, Size s) {
    if (finita || _caricate < _immagini.length) return;
    // la differenza piu' vicina non ancora trovata, entro il suo cerchio (con un po' di tolleranza per il dito)
    int? presa;
    var meglio = double.infinity;
    for (var i = 0; i < _differenze.length; i++) {
      if (_trovate.contains(i)) continue;
      final d = _differenze[i];
      final dist = math.sqrt(math.pow(((d['x'] as num) - f.dx) * s.width, 2) + math.pow(((d['y'] as num) - f.dy) * s.height, 2));
      if (dist <= (d['r'] as num) * s.width * 1.3 + 6 && dist < meglio) {
        presa = i;
        meglio = dist;
      }
    }
    if (presa == null) {
      _via?.cancel();
      setState(() {
        _errore = f;
        _erroreSu = su;
      });
      _via = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _errore = null);
      });
      return;
    }
    setState(() => _trovate.add(presa!));
    if (_trovate.length == _differenze.length) vinto('differenze', widget.partita['partita'] as String);
  }

  Widget _immagine(int su, double w) {
    final h = w * 3 / 4, s = Size(w, h);
    return GestureDetector(
      onTapUp: (e) => _tocca(su, Offset(e.localPosition.dx / w, e.localPosition.dy / h), s),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned.fill(child: Image(image: _immagini[su], fit: BoxFit.cover)),
          for (final i in _trovate)
            Positioned(
              left: ((_differenze[i]['x'] as num) - (_differenze[i]['r'] as num)) * w,
              top: (_differenze[i]['y'] as num) * h - (_differenze[i]['r'] as num) * w,
              child: Container(
                width: (_differenze[i]['r'] as num) * w * 2,
                height: (_differenze[i]['r'] as num) * w * 2,
                // niente ombra: su un cerchio vuoto scurirebbe la differenza; un filo bianco la stacca dallo sfondo
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.lightGreenAccent.shade700, width: 3, strokeAlign: BorderSide.strokeAlignCenter),
                ),
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
                ),
              ),
            ),
          if (_errore != null && _erroreSu == su)
            Positioned(
              left: _errore!.dx * w - 18,
              top: _errore!.dy * h - 18,
              child: const Icon(Icons.close_rounded, color: rosso, size: 36, shadows: [Shadow(color: Colors.white, blurRadius: 6)]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pronte = _caricate >= _immagini.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Differenze')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Trovate ${_trovate.length} di ${_differenze.length}',
              style: const TextStyle(fontFamily: fontTitoli, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LayoutBuilder(builder: (context, c) {
              // due immagini 4:3 una sopra l'altra, piu' grandi possibile
              final w = math.min(c.maxWidth, (c.maxHeight - 10) / 2 * 4 / 3);
              return Stack(children: [
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [_immagine(0, w), const SizedBox(height: 10), _immagine(1, w)])),
                if (!pronte) const Center(child: CircularProgressIndicator()),
              ]);
            }),
          ),
        ),
        barraTempo(_totale),
      ]),
    );
  }
}

// ---------- Memory: 20 carte, 10 coppie ----------
class PaginaMemory extends StatefulWidget {
  final Json partita;
  const PaginaMemory({super.key, required this.partita});
  @override
  State<PaginaMemory> createState() => _PaginaMemoryState();
}

class _PaginaMemoryState extends State<PaginaMemory> with _ContoAllaRovescia {
  late final List<int> _carte; // indice dell'immagine di ogni carta
  final Set<int> _trovate = {};
  final List<int> _girate = [];
  bool _blocco = false;
  late final int _totale;

  @override
  void initState() {
    super.initState();
    final n = (widget.partita['immagini'] as List).length;
    _carte = [for (var i = 0; i < n; i++) ...[i, i]]..shuffle(math.Random());
    _totale = (widget.partita['secondi'] as num).toInt();
    avviaTempo(_totale);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final u in widget.partita['immagini'] as List) {
      precacheImage(NetworkImage(TesoroApi.instance.indirizzo(u as String)), context);
    }
  }

  void _tocca(int i) {
    if (_blocco || finita || _trovate.contains(i) || _girate.contains(i)) return;
    setState(() => _girate.add(i));
    if (_girate.length < 2) return;
    final a = _girate[0], b = _girate[1];
    if (_carte[a] == _carte[b]) {
      setState(() {
        _trovate.addAll([a, b]);
        _girate.clear();
      });
      if (_trovate.length == _carte.length) vinto('memory', widget.partita['partita'] as String);
    } else {
      _blocco = true;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _girate.clear();
          _blocco = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.partita['immagini'] as List;
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(builder: (context, c) {
              // 4 colonne e 5 righe che stanno tutte nello schermo
              final lato = math.min((c.maxWidth - 3 * 8) / 4, (c.maxHeight - 4 * 8) / 5);
              return Center(
                child: SizedBox(
                  width: lato * 4 + 24,
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < _carte.length; i++)
                      GestureDetector(
                        onTap: () => _tocca(i),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _trovate.contains(i) || _girate.contains(i)
                              ? ClipRRect(
                                  key: ValueKey('f$i'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Opacity(
                                    opacity: _trovate.contains(i) ? 0.55 : 1,
                                    child: Image.network(TesoroApi.instance.indirizzo(img[_carte[i]] as String), width: lato, height: lato, fit: BoxFit.cover),
                                  ),
                                )
                              : Container(
                                  key: ValueKey('r$i'),
                                  width: lato,
                                  height: lato,
                                  decoration: BoxDecoration(color: bluNotte, borderRadius: BorderRadius.circular(10), border: Border.all(color: oro, width: 2)),
                                  child: const Icon(Icons.diamond_outlined, color: oro),
                                ),
                        ),
                      ),
                  ]),
                ),
              );
            }),
          ),
        ),
        barraTempo(_totale),
      ]),
    );
  }
}

// ---------- Puzzle: 20 pezzi da rimettere a posto scambiandoli con due tocchi ----------
class PaginaPuzzle extends StatefulWidget {
  final Json partita;
  const PaginaPuzzle({super.key, required this.partita});
  @override
  State<PaginaPuzzle> createState() => _PaginaPuzzleState();
}

class _PaginaPuzzleState extends State<PaginaPuzzle> with _ContoAllaRovescia {
  static const _colonne = 4, _righe = 5;
  ui.Image? _immagine;
  late final List<int> _pezzi; // _pezzi[posto] = pezzo che ci sta adesso
  int? _scelto;
  late final int _totale;
  // all'inizio l'immagine si vede intera per 2 secondi (il portale non li conta), poi si mescola e parte il tempo
  bool _anteprima = true;

  @override
  void initState() {
    super.initState();
    _pezzi = List.generate(_colonne * _righe, (i) => i);
    // mescolati, ma mai gia' in ordine
    do {
      _pezzi.shuffle(math.Random());
    } while (_ordinato());
    _totale = (widget.partita['secondi'] as num).toInt();
    final stream = NetworkImage(TesoroApi.instance.indirizzo((widget.partita['immagini'] as List).first as String)).resolve(ImageConfiguration.empty);
    restano = _totale;
    stream.addListener(ImageStreamListener((info, _) {
      if (!mounted || _immagine != null) return;
      setState(() => _immagine = info.image);
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _anteprima = false);
        avviaTempo(_totale);
      });
    }));
  }

  bool _ordinato() {
    for (var i = 0; i < _pezzi.length; i++) {
      if (_pezzi[i] != i) return false;
    }
    return true;
  }

  void _tocca(int posto) {
    if (finita || _anteprima) return;
    if (_scelto == null) return setState(() => _scelto = posto);
    if (_scelto == posto) return setState(() => _scelto = null);
    setState(() {
      final x = _pezzi[_scelto!];
      _pezzi[_scelto!] = _pezzi[posto];
      _pezzi[posto] = x;
      _scelto = null;
    });
    if (_ordinato()) vinto('puzzle', widget.partita['partita'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle')),
      body: Column(children: [
        Expanded(
          child: _immagine == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(builder: (context, c) {
                    // pezzi attaccati, senza spazio: l'immagine si vede intera
                    final lato = math.min(c.maxWidth / _colonne, c.maxHeight / _righe);
                    Widget pezzo(int posto) => GestureDetector(
                          onTap: () => _tocca(posto),
                          child: AnimatedScale(
                            scale: _scelto == posto ? 0.9 : 1,
                            duration: const Duration(milliseconds: 120),
                            child: Container(
                              width: lato,
                              height: lato,
                              // il bordo del pezzo scelto sta sopra l'immagine, cosi' non la stringe
                              foregroundDecoration: _scelto == posto ? BoxDecoration(border: Border.all(color: oro, width: 4)) : null,
                              decoration: BoxDecoration(boxShadow: _scelto == posto ? const [BoxShadow(color: oro, blurRadius: 12)] : null),
                              child: CustomPaint(painter: _Pezzo(_immagine!, _anteprima ? posto : _pezzi[posto], _colonne, _righe)),
                            ),
                          ),
                        );
                    // righe e colonne fisse: con un Wrap un arrotondamento potrebbe mandare a capo l'ultimo pezzo
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (var r = 0; r < _righe; r++)
                          Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < _colonne; k++) pezzo(r * _colonne + k)]),
                      ]),
                    );
                  }),
                ),
        ),
        barraTempo(_totale),
      ]),
    );
  }
}

class _Pezzo extends CustomPainter {
  final ui.Image img;
  final int n, colonne, righe;
  _Pezzo(this.img, this.n, this.colonne, this.righe);

  @override
  void paint(Canvas canvas, Size s) {
    final w = img.width / colonne, h = img.height / righe;
    final src = Rect.fromLTWH((n % colonne) * w, (n ~/ colonne) * h, w, h);
    canvas.drawImageRect(img, src, Offset.zero & s, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_Pezzo o) => o.n != n || o.img != img;
}
