import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'api_tesoro.dart';

// Sfide del livello 1 («Riscalda i neuroni»): Memory e Puzzle, 4 colonne per 5 righe, entro il tempo scelto nel
// pannello. Il tempo lo misura il portale (dall'inizio alla fine della partita); qui c'e' il conto alla rovescia.

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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => gioco == 'memory' ? PaginaMemory(partita: partita) : PaginaPuzzle(partita: partita)));
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
    stream.addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _immagine = info.image);
    }));
    avviaTempo(_totale);
  }

  bool _ordinato() {
    for (var i = 0; i < _pezzi.length; i++) {
      if (_pezzi[i] != i) return false;
    }
    return true;
  }

  void _tocca(int posto) {
    if (finita) return;
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
                    final lato = math.min((c.maxWidth - 3 * 3) / _colonne, (c.maxHeight - 4 * 3) / _righe);
                    return Center(
                      child: SizedBox(
                        width: lato * _colonne + 9,
                        child: Wrap(spacing: 3, runSpacing: 3, children: [
                          for (var posto = 0; posto < _pezzi.length; posto++)
                            GestureDetector(
                              onTap: () => _tocca(posto),
                              child: AnimatedScale(
                                scale: _scelto == posto ? 0.9 : 1,
                                duration: const Duration(milliseconds: 120),
                                child: Container(
                                  width: lato,
                                  height: lato,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _scelto == posto ? oro : Colors.transparent, width: 4),
                                    boxShadow: _scelto == posto ? const [BoxShadow(color: oro, blurRadius: 12)] : null,
                                  ),
                                  child: CustomPaint(painter: _Pezzo(_immagine!, _pezzi[posto], _colonne, _righe)),
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
