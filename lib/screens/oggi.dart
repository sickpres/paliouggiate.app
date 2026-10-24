import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../models.dart';
import '../tema.dart';
import '../widgets/comuni.dart';
import '../widgets/icone_tratto.dart';
import 'documenti.dart';
import 'home.dart';
import 'rioni.dart';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_TELECRONACA="testo"
const _provaTelecronaca = String.fromEnvironment('PROVA_TELECRONACA');

class _Dati {
  final Edizione edizione;
  final Telecronaca? telecronaca;
  _Dati(this.edizione, this.telecronaca);
}

Future<_Dati> _carica() async {
  // la telecronaca e' un di piu': se non arriva la Home si mostra lo stesso
  final tele = _provaTelecronaca.isNotEmpty ? Future.value(Telecronaca(_provaTelecronaca, DateTime.now())) : Api.instance.telecronaca().catchError((_) => null);
  final r = await Future.wait<Object?>([Api.instance.edizione(), tele]);
  return _Dati(r[0] as Edizione, r[1] as Telecronaca?);
}

/// Scheda Home: una sola schermata, la foto della piazza con la scritta del Palio, il motto, le date, il pulsante
/// per il programma e le scorciatoie. Tutta la scheda e' scura (temaHome).
class PaginaOggi extends StatelessWidget {
  const PaginaOggi({super.key});

  @override
  Widget build(BuildContext context) {
    // senza barra in alto: la foto sale dietro ora e batteria, bianche sul cielo
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: temaHome,
        child: Scaffold(
          body: LayoutBuilder(builder: (context, c) {
            final alto = c.maxHeight;
            return Stack(children: [
              Positioned(top: 0, left: 0, right: 0, height: alto, child: const _Sfondi()),
              // la lista serve solo a trascinare per aggiornare (e a scorrere sugli schermi piu' bassi)
              DatiRemoti<_Dati>(
                carica: _carica,
                costruisci: (context, d) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [_Copertina(edizione: d.edizione, telecronaca: d.telecronaca, altezza: alto)],
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

// Foto di sfondo della Home: tutte finiscono in basso nel blu notte, il fondo della scheda (circa 850 x 1850)
final _foto = [
  'assets/home.webp',
  for (var i = 1; i <= 12; i++) 'assets/sfondi/${i.toString().padLeft(2, '0')}.webp',
];
// solo per le schermate di prova nel simulatore: --dart-define=PROVA_SFONDO=n tiene ferma la foto n di _foto
const _provaSfondo = int.fromEnvironment('PROVA_SFONDO', defaultValue: -1);

/// Sfondo della Home: le foto si alternano ogni 5 secondi con una dissolvenza morbida. L'ordine e' casuale a ogni
/// apertura dell'app e nessuna foto torna prima di averle mostrate tutte; poi si rimescola, senza ripetere subito
/// l'ultima. Si ferma mentre e' aperta un'altra scheda.
class _Sfondi extends StatefulWidget {
  const _Sfondi();

  @override
  State<_Sfondi> createState() => _SfondiState();
}

class _SfondiState extends State<_Sfondi> {
  final _caso = math.Random();
  late List<String> _giro = _mescola(null);
  int _i = 0;
  Timer? _orologio;
  // misure dello schermo e configurazione delle immagini, lette solo in didChangeDependencies: il timer non deve
  // consultare il contesto (con la pagina staccata dall'albero, per esempio con l'app in secondo piano, non si puo')
  int? _larghezza;
  ImageConfiguration _configurazione = ImageConfiguration.empty;

  // nuovo giro casuale; la prima foto non e' l'ultima del giro precedente
  List<String> _mescola(String? ultima) {
    final l = [..._foto]..shuffle(_caso);
    if (ultima != null && l.length > 1 && l.first == ultima) l.add(l.removeAt(0));
    return l;
  }

  String get _attuale => _provaSfondo >= 0 ? _foto[_provaSfondo % _foto.length] : _giro[_i];

  String get _prossima => _i + 1 < _giro.length ? _giro[_i + 1] : _giro.first;

  @override
  void initState() {
    super.initState();
    if (_provaSfondo < 0) _orologio = Timer.periodic(const Duration(seconds: 5), (_) => _avanti());
  }

  Future<void> _avanti() async {
    // solo con la Home in vista (le schede restano vive nell'IndexedStack)
    if (!mounted || schedaHome.value != 0) return;
    setState(() {
      if (++_i >= _giro.length) {
        _giro = _mescola(_giro.last);
        _i = 0;
      }
    });
    // la foto dopo si decodifica in anticipo, cosi' la dissolvenza non aspetta il caricamento
    _prepara();
  }

  // come precacheImage, ma senza contesto: si ascolta l'immagine finche' e' pronta, cosi' resta nella cache
  void _prepara() {
    final flusso = _immagine(_prossima).image.resolve(_configurazione);
    late final ImageStreamListener ascolto;
    ascolto = ImageStreamListener((_, __) => flusso.removeListener(ascolto), onError: (_, __) => flusso.removeListener(ascolto));
    flusso.addListener(ascolto);
  }

  Image _immagine(String percorso) => Image.asset(
        percorso,
        key: ValueKey(percorso),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: _larghezza,
        excludeFromSemantics: true,
        gaplessPlayback: true,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // a volte (es. app in secondo piano) la larghezza e' zero: allora si tiene quella di prima
    final larga = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
    if (larga > 0) _larghezza = larga;
    _configurazione = createLocalImageConfiguration(context);
    _prepara();
  }

  @override
  void dispose() {
    _orologio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      // la foto nuova compare sopra la vecchia, tutte e due a piena misura
      layoutBuilder: (attuale, precedenti) => Stack(fit: StackFit.expand, children: [...precedenti, if (attuale != null) attuale]),
      child: _immagine(_attuale),
    );
  }
}

/// Prima schermata della Home, alta quanto lo schermo: la scritta del Palio in alto; in basso, dove la foto diventa
/// blu notte, le date dell'edizione, il pulsante per il calendario e le scorciatoie.
class _Copertina extends StatelessWidget {
  final Edizione edizione;
  final Telecronaca? telecronaca;
  final double altezza;
  const _Copertina({required this.edizione, required this.telecronaca, required this.altezza});

  void _apri(BuildContext context, Widget pagina) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final date = intervallo(edizione.inizio, edizione.fine);
    final ombra = [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12)];
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: altezza),
      child: DecoratedBox(
        // la foto e' piu' scura in alto (dietro la scritta del Palio) e verso il basso, fino al blu notte che continua
        // sotto senza stacchi; al centro resta appena velata
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.25, 0.38, 0.55, 0.75, 1],
            colors: [Color(0x9901112D), Color(0x2601112D), Color(0x2601112D), Color(0x5901112D), Color(0xB301112D), notte],
          ),
        ),
        child: DecoratedBox(
          // in piu', a sinistra (dietro il motto e le date) piu' scura, a destra piu' chiara: la folla resta visibile
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0, 0.65],
              colors: [Color(0x8001112D), Color(0x0001112D)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // la scritta del Palio, come un marchio, e a destra i social
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: Semantics(
                    label: 'Il Palio, Uggiate con Ronago',
                    excludeSemantics: true,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('IL PALIO', style: t.textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.0, fontSize: 58, shadows: ombra)),
                      Text('UGGIATE CON RONAGO',
                          style: t.textTheme.titleMedium?.copyWith(
                              fontFamily: fontTitoli, color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: 3, shadows: ombra)),
                    ]),
                  )),
                  IconButton(
                    tooltip: 'Seguici sui social',
                    padding: const EdgeInsets.all(12),
                    onPressed: () => _foglio(context, 'Seguici sui social', const _ElencoSocial()),
                    icon: const IconaTratto('social_menu', lato: 28, colore: Colors.white, spessore: 2),
                  ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 32),
                  // il motto del Palio: la prima parola bianca, le altre in oro chiaro
                  Semantics(
                    label: 'Tradizione, gioco, comunità',
                    excludeSemantics: true,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final (parola, colore) in const [('Tradizione', Colors.white), ('Gioco', oroChiaro), ('Comunità', oroChiaro)])
                        Text(parola,
                            style: t.textTheme.displaySmall
                                ?.copyWith(fontFamily: fontTitoli, color: colore, height: 1.0, fontSize: 42, letterSpacing: 0, shadows: ombra)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  // le date dell'edizione in grande; senza date, il suo nome
                  Text(date.isNotEmpty ? date : edizione.nome,
                      style: t.textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.1, fontSize: 26, shadows: ombra)),
                  const SizedBox(height: 22),
                  // due pulsanti affiancati: il programma (scheda Calendario) e «Partecipa» (scelta del rione, con il suo gruppo WhatsApp)
                  SizedBox(
                    height: 54,
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), padding: const EdgeInsets.symmetric(horizontal: 12)),
                          onPressed: () => schedaHome.value = 1,
                          child: const FittedBox(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('Scopri il programma'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 22),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 1.5),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                            textStyle: const TextStyle(fontFamily: fontTitoli, fontSize: 19, fontWeight: FontWeight.w700), // come «Scopri il programma»
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () => _apri(context, const PaginaRioni(titolo: 'Seleziona il tuo rione')),
                          child: const FittedBox(child: Text('Partecipa')),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _Scorciatoia('radio', 'Radio Palio', () => _foglio(context, 'Radio Palio', _Diretta(telecronaca))),
                    const SizedBox(width: 10),
                    _Scorciatoia('mappa', 'Rioni', () => _apri(context, const PaginaRioni())),
                    const SizedBox(width: 10),
                    _Scorciatoia('documenti', 'Documenti', () => _apri(context, const PaginaDocumenti())),
                    const SizedBox(width: 10),
                    _Scorciatoia('ricordi', 'Ricordi', () => apriRicordi(context)),
                  ]),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Foglio che sale dal basso, scuro come la Home, con un titolo e il contenuto.
/// Il video «Ricordi» nel foglio della Home (anche dal tocco su una notifica, apri_pagina.dart).
void apriRicordi(BuildContext context) => _foglio(context, 'Ricordi', const _Ricordi());

void _foglio(BuildContext context, String titolo, Widget contenuto) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: notte,
    builder: (context) => Theme(
      data: temaHome,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(titolo, style: temaHome.textTheme.headlineSmall?.copyWith(color: Colors.white)),
            ),
            Flexible(child: SingleChildScrollView(child: contenuto)),
          ]),
        ),
      ),
    ),
  );
}

/// «Radio Palio»: l'ultima telecronaca del portale («Il Palio in diretta»), se c'e'.
class _Diretta extends StatelessWidget {
  final Telecronaca? tc;
  const _Diretta(this.tc);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (tc != null) return _SchedaTelecronaca(tc!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text("Al momento non c'è nessuna diretta. Durante il Palio qui trovi il racconto delle gare.",
          style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    );
  }
}

/// «Ricordi»: il video caricato dal pannello del portale (immagini delle edizioni passate), scaricato quando si apre.
/// Parte da solo; un tocco lo ferma o lo riprende. Senza video (o senza rete) un messaggio.
class _Ricordi extends StatefulWidget {
  const _Ricordi();

  @override
  State<_Ricordi> createState() => _RicordiState();
}

class _RicordiState extends State<_Ricordi> {
  VideoPlayerController? _video;
  VideoRicordi? _info;
  bool _pronto = false; // dati del video arrivati (o assenti)
  bool _errore = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final info = await Api.instance.ricordi();
      if (!mounted) return;
      setState(() { _info = info; _pronto = true; });
      if (info == null) return;
      final v = VideoPlayerController.networkUrl(Uri.parse('$baseUrl${info.url}'));
      _video = v;
      v.addListener(_aggiorna);
      await v.initialize();
      if (!mounted) return;
      setState(() {});
      v.play();
    } catch (_) {
      if (mounted) setState(() { _pronto = true; _errore = true; });
    }
  }

  void _aggiorna() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.removeListener(_aggiorna);
    _video?.dispose();
    super.dispose();
  }

  void _tocca() {
    final c = _video;
    if (c == null) return;
    final v = c.value;
    if (v.isPlaying) {
      c.pause();
    } else {
      if (v.position >= v.duration) c.seekTo(Duration.zero); // finito: si rivede da capo
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final nota = t.textTheme.bodyMedium?.copyWith(color: Colors.white70);
    if (_pronto && (_errore || _info == null)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(_errore ? 'Non riesco a scaricare il video: controlla la connessione e riprova.' : 'Il video dei ricordi arriverà presto.',
            style: t.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
      );
    }
    final v = _video?.value;
    final pronto = v != null && v.isInitialized;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_info != null && _info!.titolo.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_info!.titolo, style: t.textTheme.titleMedium?.copyWith(color: Colors.white))),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: pronto ? v.aspectRatio : 4 / 3,
            child: !pronto
                ? const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()))
                : Semantics(
                    button: true,
                    label: v.isPlaying ? 'Metti in pausa il video' : 'Guarda il video',
                    child: GestureDetector(
                      onTap: _tocca,
                      child: Stack(fit: StackFit.expand, children: [
                        VideoPlayer(_video!),
                        if (!v.isPlaying)
                          const ColoredBox(
                            color: Color(0x66000000),
                            child: Center(child: Icon(Icons.play_circle_fill, size: 72, color: Colors.white)),
                          ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: VideoProgressIndicator(_video!,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(playedColor: oro, bufferedColor: Colors.white38, backgroundColor: Colors.white24)),
                        ),
                      ]),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(_info != null && _info!.descrizione.isNotEmpty ? _info!.descrizione : 'Immagini delle edizioni passate del Palio dei rioni.', style: nota),
      ]),
    );
  }
}

/// «Social»: le pagine Facebook e Instagram del Palio (pulsante in alto a destra nella Home).
class _ElencoSocial extends StatelessWidget {
  const _ElencoSocial();

  @override
  Widget build(BuildContext context) => Column(children: [for (final c in _canali) _SchedaCanale(c)]);
}

/// Scorciatoia della copertina: riquadro bianco con icona a tratto gialla ed etichetta blu notte.
class _Scorciatoia extends StatelessWidget {
  final String icona;
  final String etichetta;
  final VoidCallback onTap;
  const _Scorciatoia(this.icona, this.etichetta, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: Colors.white,
          // angoli come nel mockup, un po' meno arrotondati del pulsante
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                IconaTratto(icona, lato: 30, colore: oro, spessore: 2),
                const SizedBox(height: 6),
                Text(etichetta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: bluNotte, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}

class _Canale {
  final String nome;
  final String dettaglio;
  final String url;
  final Widget icona;
  const _Canale(this.nome, this.dettaglio, this.url, this.icona);
}

/// Logo ufficiale del social (assets/facebook.png, assets/instagram.png), con gli angoli arrotondati.
class _Marchio extends StatelessWidget {
  final String immagine;
  const _Marchio(this.immagine);

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(immagine, width: 44, height: 44, fit: BoxFit.cover),
      );
}

// pagine social del Palio (i nomi sono i titoli pubblici delle pagine)
const _canali = [
  _Canale('Palio dei Rioni di Uggiate con Ronago', 'Facebook', 'https://www.facebook.com/profile.php?id=61589423978361&locale=it_IT',
      _Marchio('assets/facebook.png')),
  _Canale('@palio.uggiateconronago', 'Instagram', 'https://www.instagram.com/palio.uggiateconronago/', _Marchio('assets/instagram.png')),
];

/// Pagina social del Palio: con l'app Facebook o Instagram installata il link si apre li', altrimenti nel browser.
class _SchedaCanale extends StatelessWidget {
  final _Canale c;
  const _SchedaCanale(this.c);

  Future<void> _apri(BuildContext context) async {
    final avvisi = ScaffoldMessenger.of(context);
    if (!await launchUrl(Uri.parse(c.url), mode: LaunchMode.externalApplication)) {
      avvisi.showSnackBar(const SnackBar(content: Text('Impossibile aprire il collegamento')));
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: c.icona,
          title: Text(c.nome, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(c.dettaglio),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _apri(context),
        ),
      );
}

class _SchedaTelecronaca extends StatelessWidget {
  final Telecronaca tc;
  const _SchedaTelecronaca(this.tc);

  String _quando() {
    final c = tc.creato;
    if (c == null) return '';
    final ora = '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}';
    return stessoGiorno(c, DateTime.now()) ? 'Ultimo aggiornamento oggi alle $ora' : 'Ultimo aggiornamento ${giornoLungo(c).toLowerCase()} alle $ora';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final q = _quando();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: notteScheda,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: oro, width: 1.2)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.mic, size: 20, color: oro),
            const SizedBox(width: 8),
            Text('IL PALIO IN DIRETTA', style: t.textTheme.labelLarge?.copyWith(color: oro, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(tc.testo, style: t.textTheme.bodyLarge?.copyWith(color: Colors.white, height: 1.4)),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(q, style: t.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ],
        ]),
      ),
    );
  }
}
