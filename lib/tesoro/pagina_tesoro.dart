import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../push.dart' show chiaveRione;
import '../tema.dart';
import '../widgets/comuni.dart';
import 'api_tesoro.dart';
import 'classifica_amici.dart';
import 'info.dart';
import 'sfide.dart';
import 'tavolo.dart';

/// «Il Tesoro del Palio»: si apre dal bottone della Home. Al primo accesso si scelgono rione e avatar; poi in alto
/// restano avatar e rione (a sinistra) e la casetta per tornare alla Home (a destra); in basso Mappa, Sfide,
/// Classifica e Amici del Palio.
class PaginaTesoro extends StatefulWidget {
  const PaginaTesoro({super.key});
  @override
  State<PaginaTesoro> createState() => _PaginaTesoroState();
}

class _PaginaTesoroState extends State<PaginaTesoro> {
  Json? _io; // stato del giocatore (GET /api/tesoro/io)
  Json? _cfg; // configurazione del gioco (sfide, tempi...)
  Object? _errore;
  bool _iscritto = false;
  bool _caricato = false;
  bool _posizioneBloccata = false;
  int _scheda = 1; // 0 Info, 1 Mappa, 2 Sfide, 3 Classifica, 4 Amici: si apre sulla Mappa
  int _giro = 0; // cambia a ogni apertura di Classifica e Amici, cosi' si ricaricano

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final iscritto = await TesoroApi.instance.iscritto();
      final r = await Future.wait<Object?>([TesoroApi.instance.config(), iscritto ? TesoroApi.instance.io() : Future.value(null), posizioneBloccata()]);
      if (!mounted) return;
      setState(() {
        _cfg = r[0] as Json;
        _io = r[1] as Json?;
        _iscritto = _io != null;
        _posizioneBloccata = r[2] as bool;
        _errore = null;
        _caricato = true;
      });
    } on ApiException catch (e) {
      // 401: il giocatore non c'e' piu' (gioco azzerato): si torna all'iscrizione
      if (!mounted) return;
      setState(() {
        if (e.status == 401) {
          _iscritto = false;
          _io = null;
        } else {
          _errore = e;
        }
        _caricato = true;
      });
      if (e.status == 401) _carica();
    } catch (e) {
      if (mounted) setState(() => (_errore = e, _caricato = true));
    }
  }

  Future<void> aggiorna() => _carica();

  @override
  Widget build(BuildContext context) {
    if (!_caricato) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errore != null || _cfg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Il Tesoro del Palio')),
        body: Center(
          child: Messaggio(
            icona: Icons.cloud_off,
            titolo: 'Impossibile caricare il gioco',
            testo: _errore is ApiException ? _errore.toString() : 'Riprova tra poco.',
            azione: FilledButton.tonalIcon(onPressed: _carica, icon: const Icon(Icons.refresh), label: const Text('Riprova')),
          ),
        ),
      );
    }
    // chi si e' appena iscritto vede prima «Info», cioe' come si gioca
    if (!_iscritto) {
      return PaginaIscrizione(onFatto: () {
        _scheda = 0;
        return _carica();
      });
    }
    final g = _io!['giocatore'] as Json;
    final pagine = [
      PaginaInfo(cfg: _cfg!),
      _Mappa(io: _io!, cfg: _cfg!, aggiorna: aggiorna, vaiAlleSfide: () => setState(() => _scheda = 2)),
      PaginaSfide(io: _io!, aggiorna: aggiorna),
      ClassificaTesoro(key: ValueKey('c$_giro')),
      AmiciDelPalio(key: ValueKey('a$_giro')),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 12,
        automaticallyImplyLeading: false, // a sinistra avatar e rione; per tornare alla Home c'e' la casetta a destra
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: g['modificabile'] == true
              ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaginaIscrizione(modifica: g, onFatto: _carica)))
              : null,
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundImage: NetworkImage('$baseUrl/api/tesoro/immagini/${g['avatar_id']}')),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // nome intero anche se lungo (es. «Fantasma del Campanile»): si rimpicciolisce invece di tagliarsi
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${g['avatar']}', maxLines: 1, style: const TextStyle(fontFamily: fontTitoli, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                Text('${g['rione']} · ${g['punti']} punti', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
        actions: [
          IconButton(tooltip: 'Torna alla Home', icon: const Icon(Icons.home_outlined, size: 28), onPressed: () => Navigator.of(context).pop()),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        if (_posizioneBloccata)
          const AvvisoPermessi(testo: 'Per giocare servono la fotocamera e la posizione: sbloccale nelle impostazioni dell\'app.'),
        if (_cfg!['finito'] == true)
          const Padding(padding: EdgeInsets.all(12), child: Text('Il Tesoro del Palio è finito: la classifica resta consultabile.')),
        Expanded(child: IndexedStack(index: _scheda, children: pagine)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _scheda,
        onDestinationSelected: (i) {
          setState(() => (_scheda = i, _giro++));
          if (i == 1 || i == 2) _carica();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'Info'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mappa'),
          NavigationDestination(icon: Icon(Icons.extension_outlined), selectedIcon: Icon(Icons.extension), label: 'Sfide'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Classifica'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Amici'),
        ],
      ),
    );
  }
}

// ---------- primo accesso (e modifica nel livello 1): rione e avatar ----------
class PaginaIscrizione extends StatefulWidget {
  final Json? modifica; // giocatore da modificare; null = iscrizione
  final Future<void> Function() onFatto;
  const PaginaIscrizione({super.key, this.modifica, required this.onFatto});
  @override
  State<PaginaIscrizione> createState() => _PaginaIscrizioneState();
}

class _PaginaIscrizioneState extends State<PaginaIscrizione> {
  List<Rione>? _rioni;
  List<Json>? _avatar;
  int? _rione;
  int? _scelto;
  final _invito = TextEditingController();
  bool _invio = false;

  @override
  void initState() {
    super.initState();
    _rione = widget.modifica?['rione_id'] as int?;
    _scelto = widget.modifica?['avatar_id'] as int?;
    _carica();
  }

  Future<void> _carica() async {
    final r = await prova(context, () => Future.wait<Object>([rioniInCache(), TesoroApi.instance.avatar(), SharedPreferences.getInstance()]));
    if (r == null || !mounted) return;
    setState(() {
      _rioni = r[0] as List<Rione>;
      _avatar = r[1] as List<Json>;
      // il rione gia' scelto nell'app (filtro della pallavolo), se c'e'
      _rione ??= (r[2] as SharedPreferences).getInt(chiaveRione);
      if (!_rioni!.any((x) => x.id == _rione)) _rione = null;
    });
  }

  Future<void> _invia() async {
    setState(() => _invio = true);
    final ok = await prova(context, () async {
      if (widget.modifica != null) {
        await TesoroApi.instance.modifica({'avatar_id': _scelto, 'rione_id': _rione});
      } else {
        await TesoroApi.instance.iscrivi(avatar: _scelto!, rione: _rione!, invito: _invito.text);
      }
      return true;
    });
    if (!mounted) return;
    setState(() => _invio = false);
    if (ok == true) {
      await widget.onFatto();
      if (widget.modifica != null && mounted) Navigator.of(context).pop();
    } else {
      _carica(); // l'avatar potrebbe essere stato preso da un altro
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final nuovo = widget.modifica == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(nuovo ? 'Il Tesoro del Palio' : 'Avatar e rione'),
        automaticallyImplyLeading: !nuovo,
        actions: [if (nuovo) IconButton(tooltip: 'Torna alla Home', icon: const Icon(Icons.home_outlined, size: 28), onPressed: () => Navigator.of(context).pop())],
      ),
      body: _rioni == null || _avatar == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              if (nuovo)
                Text('Una caccia al tesoro in tre livelli, prima del Palio. Scegli il tuo rione e il tuo avatar: '
                    'sarà il tuo nome in classifica.', style: t.textTheme.bodyLarge),
              if (!nuovo) Text('Puoi cambiarli fino a quando sei al livello 1.', style: t.textTheme.bodyLarge),
              const Sezione('Il tuo rione'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in _rioni!)
                  ChoiceChip(
                    avatar: SegnoRione(rione: r, colore: r.colore, lato: 22),
                    label: Text(r.nome),
                    selected: _rione == r.id,
                    onSelected: (_) => setState(() => _rione = r.id),
                  ),
              ]),
              const Sezione('Il tuo avatar'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
                children: [
                  for (final a in _avatar!.where((a) => a['libero'] == true || a['id'] == widget.modifica?['avatar_id']))
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _scelto = a['id'] as int),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _scelto == a['id'] ? oro : Colors.transparent, width: 3),
                          color: t.colorScheme.surfaceContainerLowest,
                        ),
                        child: Column(children: [
                          Expanded(child: ClipOval(child: Image.network(TesoroApi.instance.indirizzo(a['foto'] as String), fit: BoxFit.cover))),
                          const SizedBox(height: 6),
                          // fino a due righe, centrate: i nomi sono di due o tre parole
                          SizedBox(
                            height: 34,
                            child: Center(
                              child: Text('${a['nome']}',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.15)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
              if (_avatar!.every((a) => a['libero'] != true) && nuovo)
                const Padding(padding: EdgeInsets.only(top: 8), child: Text('Gli avatar sono finiti: riprova più tardi.')),
              if (nuovo) ...[
                const Sezione('Il codice di un amico (facoltativo)'),
                TextField(
                  controller: _invito,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'es. RTD0125'),
                ),
                const SizedBox(height: 4),
                Text('Se un amico ti ha fatto scaricare l\'app, inserisci il suo codice: lo aiuti a completare una sfida.',
                    style: t.textTheme.bodySmall),
              ],
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _rione == null || _scelto == null || _invio ? null : _invia,
                child: Text(_invio ? 'Un momento…' : nuovo ? 'Inizia a giocare' : 'Salva'),
              ),
            ]),
    );
  }
}

// ---------- mappa dei tre livelli ----------
// Sfondo disegnato come la mappa dei rioni (assets/mappa_tesoro.webp, scripts/mappa-tesoro.js); sopra, per ogni
// livello, una zona colorata e uno «stemma» tondo come quelli dei rioni, il sentiero tratteggiato e il tesoro in riva al lago.
const _coloriLivello = [Color(0xFFE0A100), Color(0xFF2F6FD0), Color(0xFFD23B3B)];
const _grigio = Color(0xFF8A8F98);
const _verde = Color(0xFF2E7D32);

class _Mappa extends StatelessWidget {
  final Json io;
  final Json cfg;
  final Future<void> Function() aggiorna;
  final VoidCallback vaiAlleSfide;
  const _Mappa({required this.io, required this.cfg, required this.aggiorna, required this.vaiAlleSfide});

  // posizione dei tre livelli e del tesoro (frazioni di larghezza e altezza)
  static const _punti = [Offset(0.27, 0.79), Offset(0.66, 0.53), Offset(0.30, 0.29)];
  static const _tesoro = Offset(0.74, 0.13);

  @override
  Widget build(BuildContext context) {
    final livello = (io['giocatore'] as Json)['livello'] as int;
    final fatte = io['fatte'] as Json;
    final sfide = [for (final s in cfg['sfide'] as List) Map<String, dynamic>.from(s as Map)];
    return RefreshIndicator(
      onRefresh: aggiorna,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              Positioned.fill(child: Image.asset('assets/mappa_tesoro.webp', fit: BoxFit.cover)),
              Positioned.fill(child: CustomPaint(painter: _Sentiero([..._punti, _tesoro], livello))),
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: _punti[i].dx * w - 55,
                  top: _punti[i].dy * h - 36,
                  child: _Tappa(
                    numero: i + 1,
                    stato: i + 1 < livello ? 'fatto' : i + 1 == livello ? 'corrente' : 'chiuso',
                    fatte: sfide.where((s) => s['livello'] == i + 1 && fatte.containsKey(s['chiave'])).length,
                    totale: sfide.where((s) => s['livello'] == i + 1).length,
                    onTap: i + 1 > livello
                        ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa le sfide del livello precedente per sbloccarlo.')))
                        : () => mostraLivello(context, i + 1, io, sfide.where((s) => s['livello'] == i + 1).toList(), fatte, aggiorna, vaiAlleSfide),
                  ),
                ),
              Positioned(left: _tesoro.dx * w - 34, top: _tesoro.dy * h - 34, child: _Forziere(aperto: livello >= 3)),
            ]),
          ),
        );
      }),
    );
  }
}

/// Zone colorate dei livelli (come le aree dei rioni) e il sentiero tratteggiato che le unisce fino al tesoro.
class _Sentiero extends CustomPainter {
  final List<Offset> punti;
  final int livello;
  _Sentiero(this.punti, this.livello);

  @override
  void paint(Canvas canvas, Size s) {
    final p = punti.map((x) => Offset(x.dx * s.width, x.dy * s.height)).toList();
    // zone: un cerchio morbido intorno a ogni tappa, del colore del livello (grigio se ancora chiuso)
    for (var i = 0; i < 3; i++) {
      final colore = i + 1 > livello ? _grigio : _coloriLivello[i];
      final r = s.shortestSide * 0.2;
      canvas.drawCircle(p[i], r, Paint()..color = colore.withValues(alpha: 0.22));
      canvas.drawCircle(p[i], r, Paint()
        ..color = colore.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
    }
    // sentiero: tratteggio marrone; la parte gia' percorsa e' piena e piu' spessa
    for (var i = 1; i < p.length; i++) {
      final a = p[i - 1], b = p[i];
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo((a.dx + b.dx) / 2 + (i.isOdd ? 70 : -70), (a.dy + b.dy) / 2, b.dx, b.dy);
      final fatto = i < livello;
      final tratto = Paint()
        ..color = fatto ? const Color(0xFF6B4219) : const Color(0xFF6B4219).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = fatto ? 7 : 5
        ..strokeCap = StrokeCap.round;
      for (final m in path.computeMetrics()) {
        for (double d = 0; d < m.length; d += 24) {
          canvas.drawPath(m.extractPath(d, d + 12), tratto);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Sentiero o) => o.livello != livello;
}

/// Tappa di un livello: stemma tondo bianco con l'anello del colore del livello, come quelli dei rioni, e sotto
/// un'etichetta con il nome e le sfide completate.
class _Tappa extends StatelessWidget {
  final int numero;
  final String stato; // fatto, corrente, chiuso
  final int fatte, totale;
  final VoidCallback onTap;
  const _Tappa({required this.numero, required this.stato, required this.fatte, required this.totale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chiuso = stato == 'chiuso';
    final colore = chiuso ? _grigio : stato == 'fatto' ? _verde : _coloriLivello[numero - 1];
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: colore, width: 6),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Center(
              child: chiuso
                  ? const Icon(Icons.lock, color: _grigio, size: 32)
                  : stato == 'fatto'
                      ? const Icon(Icons.check_rounded, color: _verde, size: 40)
                      : Text('$numero', style: TextStyle(fontFamily: fontTitoli, fontSize: 36, fontWeight: FontWeight.w800, color: colore)),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
            child: Column(children: [
              Text('Livello $numero', style: const TextStyle(fontFamily: fontTitoli, fontWeight: FontWeight.w800, fontSize: 15, color: bluNotte)),
              if (!chiuso) Text('$fatte di $totale', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colore)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Il tesoro in riva al lago: uno stemma oro con la gemma e la X rossa della mappa; spento finche' non si arriva al livello 3.
class _Forziere extends StatelessWidget {
  final bool aperto;
  const _Forziere({required this.aperto});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: aperto ? oro : Colors.white.withValues(alpha: 0.85),
            border: Border.all(color: aperto ? const Color(0xFF9A6500) : _grigio, width: 5),
            boxShadow: aperto ? const [BoxShadow(color: oro, blurRadius: 18)] : const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Icon(Icons.diamond, size: 34, color: aperto ? Colors.white : _grigio),
        ),
        const Positioned(right: -2, bottom: -4, child: Text('✕', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFFD23B3B)))),
      ]),
    );
  }
}

// ---------- le sfide di un livello ----------
Future<void> mostraLivello(BuildContext context, int n, Json io, List<Json> sfide, Json fatte, Future<void> Function() aggiorna, VoidCallback vaiAlleSfide) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scorri) => ListView(controller: scorri, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Text('Livello $n', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        for (final s in sfide)
          _SchedaSfida(sfida: s, io: io, fatta: fatte.containsKey(s['chiave']), aggiorna: () async {
            await aggiorna();
            if (context.mounted) Navigator.of(context).pop();
          }, vaiAlleSfide: () {
            Navigator.of(context).pop();
            vaiAlleSfide();
          }),
      ]),
    ),
  );
}

class _SchedaSfida extends StatefulWidget {
  final Json sfida;
  final Json io;
  final bool fatta;
  final Future<void> Function() aggiorna;
  final VoidCallback vaiAlleSfide;
  const _SchedaSfida({required this.sfida, required this.io, required this.fatta, required this.aggiorna, required this.vaiAlleSfide});
  @override
  State<_SchedaSfida> createState() => _SchedaSfidaState();
}

class _SchedaSfidaState extends State<_SchedaSfida> {
  final _testo = TextEditingController();
  bool _lavoro = false;

  Future<void> _esegui(Future<bool?> Function() fn) async {
    setState(() => _lavoro = true);
    final ok = await fn();
    if (!mounted) return;
    setState(() => _lavoro = false);
    if (ok == true) await widget.aggiorna();
  }

  // «Affina l'occhio»: la foto scattata vicino all'oggetto, con la posizione del telefono
  Future<bool?> _occhio() async {
    final foto = await prova(context, scattaFoto);
    if (foto == null || !mounted) return null;
    return prova(context, () async {
      final pos = await posizioneAttuale();
      final id = await TesoroApi.instance.caricaFoto('occhio', foto);
      await TesoroApi.instance.occhio(pos, id);
      return true;
    });
  }

  Future<bool?> _tesoro() async {
    final qr = await leggiQr(context);
    if (qr == null || !mounted) return null;
    final r = await prova(context, () => TesoroApi.instance.tesoro(qr));
    if (r == null || !mounted) return null;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(r['vinto'] == true ? 'Hai trovato il tesoro!' : 'Il tesoro è già stato trovato'),
        content: Text(r['vinto'] == true ? 'Sei il primo: i punti sono tuoi e del tuo rione.' : 'Qualcuno è arrivato prima di te. Ottima caccia comunque!'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = widget.sfida;
    final io = widget.io;
    final g = io['giocatore'] as Json;
    final chiave = s['chiave'] as String;
    final azioni = <Widget>[];
    if (!widget.fatta) {
      switch (chiave) {
        case 'diffondi':
          final inviti = io['inviti'] as Json;
          azioni.addAll([
            Text('Il tuo codice', style: t.textTheme.labelLarge),
            SelectableText('${g['codice']}', style: const TextStyle(fontFamily: fontTitoli, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 3)),
            Text('Amici iscritti col tuo codice: ${inviti['fatti']} su ${inviti['richiesti']}'),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.share),
              label: const Text('Invita su WhatsApp'),
              onPressed: () => launchUrl(
                  Uri.parse('https://wa.me/?text=${Uri.encodeComponent('Gioca con me a «Il Tesoro del Palio»! Scarica l\'app del Palio: $baseUrl/app/ e inserisci il mio codice ${g['codice']}')}'),
                  mode: LaunchMode.externalApplication),
            ),
          ]);
        case 'neuroni':
          final n = io['neuroni'] as Json;
          azioni.addAll([
            Text('Memory: ${n['memory'] == null ? 'da completare' : 'fatto in ${n['memory']} s'} · Puzzle: ${n['puzzle'] == null ? 'da completare' : 'fatto in ${n['puzzle']} s'}'),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: widget.vaiAlleSfide, child: const Text('Vai alle sfide')),
          ]);
        case 'occhio':
          final o = io['oggetto'] as Json?;
          azioni.addAll(o == null
              ? [const Text('L\'oggetto misterioso non è ancora pronto: torna più tardi.')]
              : [
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(TesoroApi.instance.indirizzo(o['foto'] as String), fit: BoxFit.cover)),
                  const SizedBox(height: 8),
                  FilledButton.icon(icon: const Icon(Icons.photo_camera), label: const Text('Fotografa l\'oggetto'), onPressed: _lavoro ? null : () => _esegui(_occhio)),
                ]);
        case 'enigma':
          final e = io['enigma'] as Json?;
          azioni.addAll(e == null || e['messaggio'] == null
              ? [const Text('L\'enigma non è ancora pronto: torna più tardi.')]
              : [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF3E2B8), borderRadius: BorderRadius.circular(12)),
                    child: Text('${e['messaggio']}', style: const TextStyle(fontSize: 17, color: Color(0xFF3F2410), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _testo, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'La tua parola chiave')),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _lavoro
                        ? null
                        : () => _esegui(() async {
                              final avvisi = ScaffoldMessenger.of(context);
                              final r = await prova(context, () => TesoroApi.instance.enigma(_testo.text));
                              if (r != null && r['giusta'] != true) {
                                avvisi.showSnackBar(const SnackBar(content: Text('Non è la parola giusta: riprova.')));
                              }
                              return r?['giusta'] == true;
                            }),
                    child: const Text('Verifica'),
                  ),
                ]);
        case 'bar':
          azioni.add(io['fatte'] is Map && (io['fatte'] as Json).containsKey('enigma')
              ? FilledButton.icon(
                  icon: const Icon(Icons.local_bar),
                  label: const Text('Al tavolo'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaTavolo()));
                    await widget.aggiorna();
                  })
              : const Text('Prima risolvi l\'enigma: al tavolo serve la tua parola chiave.'));
        case 'frammenti':
          final tes = io['tesoro'] as Json?;
          if (tes != null && tes['pronto'] != true) {
            // finite le pergamene del pannello: il frammento arriva quando se ne aggiunge una
            azioni.add(const Text('La vostra pergamena non è ancora pronta: torna più tardi.'));
          } else if (tes != null && tes['trovato'] == true) {
            azioni.add(Text(tes['mio'] == true
                ? 'Hai trovato il tesoro!'
                : 'Il tesoro è stato trovato da ${(tes['vincitore'] as Json?)?['avatar'] ?? 'un altro giocatore'} (${(tes['vincitore'] as Json?)?['rione'] ?? ''}).'));
          } else {
            azioni.addAll([
              if (io['frammento'] != null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Il tuo frammento'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => PaginaFrammento(foto: (io['frammento'] as Json)['foto'] as String))),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(icon: const Icon(Icons.qr_code_scanner), label: const Text('Ho trovato il tesoro'), onPressed: _lavoro ? null : () => _esegui(_tesoro)),
            ]);
          }
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _IconaSfida(chiave: chiave, fatta: widget.fatta),
            const SizedBox(width: 12),
            Expanded(child: Text('${s['titolo']}', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            _Punti(punti: (s['punti'] as num).toInt(), fatta: widget.fatta),
          ]),
          const SizedBox(height: 6),
          Text('${s['testo']}'),
          if (azioni.isNotEmpty) ...[const SizedBox(height: 12), ...azioni],
          if (_lavoro) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ]),
      ),
    );
  }
}

// icona di ogni sfida, su un tondo del colore del suo livello (verde quando e' completata)
const _iconeSfide = {
  'diffondi': Icons.campaign_rounded,
  'neuroni': Icons.psychology_rounded,
  'occhio': Icons.visibility_rounded,
  'enigma': Icons.key_rounded,
  'bar': Icons.local_bar_rounded,
  'frammenti': Icons.map_rounded,
};
const _livelloSfide = {'diffondi': 1, 'neuroni': 1, 'occhio': 1, 'enigma': 2, 'bar': 2, 'frammenti': 3};

class _IconaSfida extends StatelessWidget {
  final String chiave;
  final bool fatta;
  const _IconaSfida({required this.chiave, required this.fatta});

  @override
  Widget build(BuildContext context) {
    final colore = fatta ? _verde : _coloriLivello[(_livelloSfide[chiave] ?? 1) - 1];
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: colore.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: colore, width: 2.5)),
        child: Icon(_iconeSfide[chiave] ?? Icons.flag_rounded, color: colore, size: 26),
      ),
      if (fatta)
        const Positioned(right: -3, bottom: -3, child: CircleAvatar(radius: 10, backgroundColor: _verde, child: Icon(Icons.check, size: 14, color: Colors.white))),
    ]);
  }
}

/// Punti della sfida in evidenza: pillola oro con il numero grande; verde con la spunta quando sono gia' presi.
class _Punti extends StatelessWidget {
  final int punti;
  final bool fatta;
  const _Punti({required this.punti, required this.fatta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      decoration: BoxDecoration(
        color: fatta ? _verde : oro,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: (fatta ? _verde : oro).withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('+$punti', style: TextStyle(fontFamily: fontTitoli, fontSize: 24, height: 1.05, fontWeight: FontWeight.w800, color: fatta ? Colors.white : bluNotte)),
        Text(fatta ? 'presi' : 'punti', style: TextStyle(fontSize: 11, height: 1, fontWeight: FontWeight.w800, color: fatta ? Colors.white : bluNotte)),
      ]),
    );
  }
}

/// Il frammento della pergamena a tutto schermo, senza spiegazioni: va affiancato a quelli degli altri tre.
class PaginaFrammento extends StatelessWidget {
  final String foto; // indirizzo del frammento (cambia con la pergamena, cosi' non resta in cache quello vecchio)
  const PaginaFrammento({super.key, required this.foto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: Image.network(
              TesoroApi.instance.indirizzo(foto),
              headers: TesoroApi.instance.intestazioni,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(child: Text('Frammento non disponibile', style: TextStyle(color: Colors.white))),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.of(context).pop()),
          ),
        ]),
      ),
    );
  }
}
