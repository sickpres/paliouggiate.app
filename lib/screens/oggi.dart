import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final tele = _provaTelecronaca.isNotEmpty
      ? Future.value(Telecronaca(_provaTelecronaca, DateTime.now()))
      : Api.instance.telecronaca().catchError((_) => null);
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
    if (mounted) precacheImage(_immagine(_prossima).image, context);
  }

  Image _immagine(String percorso) => Image.asset(
        percorso,
        key: ValueKey(percorso),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
        excludeFromSemantics: true,
        gaplessPlayback: true,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_immagine(_prossima).image, context);
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
                // la scritta del Palio, come un marchio
                Semantics(
                  label: 'Il Palio, Uggiate con Ronago',
                  excludeSemantics: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('IL PALIO',
                        style: t.textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.0, fontSize: 58, shadows: ombra)),
                    Text('UGGIATE CON RONAGO',
                        style: t.textTheme.titleMedium?.copyWith(
                            fontFamily: fontTitoli, color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: 3, shadows: ombra)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 32),
                  // il motto del Palio: la prima parola bianca, le altre in oro chiaro
                  Semantics(
                    label: 'Tradizione, gioco, comunità',
                    excludeSemantics: true,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final (parola, colore) in const [('Tradizione', Colors.white), ('Gioco', oroChiaro), ('Comunità', oroChiaro)])
                        Text(parola,
                            style: t.textTheme.displaySmall?.copyWith(
                                fontFamily: fontTitoli, color: colore, height: 1.0, fontSize: 42, letterSpacing: 0, shadows: ombra)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  // le date dell'edizione in grande; senza date, il suo nome
                  Text(date.isNotEmpty ? date : edizione.nome,
                      style: t.textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.1, fontSize: 26, shadows: ombra)),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () => schedaHome.value = 1,
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Scopri il programma'),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward, size: 22),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _Scorciatoia('radio', 'Radio Palio', () => _foglio(context, 'Radio Palio', _Diretta(telecronaca))),
                    const SizedBox(width: 10),
                    _Scorciatoia('mappa', 'Rioni', () => _apri(context, const PaginaRioni())),
                    const SizedBox(width: 10),
                    _Scorciatoia('documenti', 'Documenti', () => _apri(context, const PaginaDocumenti())),
                    const SizedBox(width: 10),
                    _Scorciatoia('social_menu', 'Social', () => _foglio(context, 'Seguici sui social', const _ElencoSocial())),
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

/// «Social»: le pagine Facebook e Instagram del Palio.
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
  _Canale('@palio.uggiateconronago', 'Instagram', 'https://www.instagram.com/palio.uggiateconronago/',
      _Marchio('assets/instagram.png')),
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
            Text('IL PALIO IN DIRETTA',
                style: t.textTheme.labelLarge?.copyWith(color: oro, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
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
