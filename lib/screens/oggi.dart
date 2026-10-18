import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
import '../widgets/icone_tratto.dart';
import '../widgets/mappa.dart';
import 'mappa.dart';
import 'calendario.dart';
import 'documenti.dart';
import 'sponsor.dart';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_TELECRONACA="testo"
const _provaTelecronaca = String.fromEnvironment('PROVA_TELECRONACA');
// --dart-define=PROVA_FONDO=true porta la Home in fondo (per fotografare la mappa)
const _provaFondo = bool.fromEnvironment('PROVA_FONDO');

class _Dati {
  final Edizione edizione;
  final List<Voce> voci;
  final Telecronaca? telecronaca;
  _Dati(this.edizione, this.voci, this.telecronaca);
}

Future<_Dati> _carica() async {
  // la telecronaca e' un di piu': se non arriva la Home si mostra lo stesso
  final tele = _provaTelecronaca.isNotEmpty
      ? Future.value(Telecronaca(_provaTelecronaca, DateTime.now()))
      : Api.instance.telecronaca().catchError((_) => null);
  final r = await Future.wait<Object?>([Api.instance.edizione(), Api.instance.calendario(), tele]);
  return _Dati(r[0] as Edizione, r[1] as List<Voce>, r[2] as Telecronaca?);
}

/// Scheda Home: gli appuntamenti di oggi o, se oggi non c'e' niente, il prossimo giorno di gare.
class PaginaOggi extends StatelessWidget {
  const PaginaOggi({super.key});

  @override
  Widget build(BuildContext context) {
    // senza barra in alto: l'immagine con il logo (Uggiate al tramonto) resta ferma in testa e sale dietro
    // ora e batteria, bianche sul tramonto; sotto scorre il resto della pagina
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // assets/header.webp: 1290 x 726 (la larghezza del telefono piu' grande a 3x), decodificata alla larghezza dello schermo
          AspectRatio(
            aspectRatio: 1290 / 726,
            child: Image.asset('assets/header.webp',
                fit: BoxFit.cover,
                cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
                semanticLabel: 'Palio dei Rioni, Uggiate con Ronago'),
          ),
          Expanded(
            // la lista parte subito sotto l'immagine: niente spazio per ora e batteria
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: DatiRemoti<_Dati>(carica: _carica, costruisci: (context, d) => _Contenuto(d)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Contenuto extends StatelessWidget {
  final _Dati d;
  const _Contenuto(this.d);

  DateTime _giorno(DateTime x) => DateTime(x.year, x.month, x.day);

  String? _stato(DateTime oggi) {
    final ini = d.edizione.inizio, fine = d.edizione.fine;
    if (ini == null) return null;
    final mancano = _giorno(ini).difference(oggi).inDays;
    if (mancano > 1) return 'Mancano $mancano giorni al Palio';
    if (mancano == 1) return 'Il Palio comincia domani';
    if (fine != null && oggi.isAfter(_giorno(fine))) return 'Questa edizione si è conclusa';
    if (fine != null) {
      final n = oggi.difference(_giorno(ini)).inDays + 1;
      final tot = _giorno(fine).difference(_giorno(ini)).inDays + 1;
      return 'Giorno $n di $tot';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final oggi = _giorno(oggiApp());
    final diOggi = d.voci.where((v) => stessoGiorno(v.data, oggi)).toList();
    final dopo = d.voci.where((v) => _giorno(v.data).isAfter(oggi)).toList();
    final prossimo = dopo.isEmpty ? <Voce>[] : dopo.where((v) => stessoGiorno(v.data, dopo.first.data)).toList();
    final stato = _stato(oggi);

    final scorri = _provaFondo ? ScrollController() : null;
    if (scorri != null) {
      // di nuovo dopo qualche secondo: mappa, sponsor e social arrivano dopo e allungano la pagina
      for (final s in const [3, 8]) {
        Future.delayed(Duration(seconds: s), () {
          if (scorri.hasClients) scorri.jumpTo(scorri.position.maxScrollExtent);
        });
      }
    }
    return ListView(
      controller: scorri,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 16),
        if (d.edizione.nome.isNotEmpty)
          Text('Uggiate con Ronago · ${d.edizione.nome}', textAlign: TextAlign.center, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(intervallo(d.edizione.inizio, d.edizione.fine),
            textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        if (stato != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.flag, size: 18),
                label: Text(stato),
                backgroundColor: t.colorScheme.surfaceContainerLowest,
              ),
            ),
          ),
        if (d.telecronaca != null) _SchedaTelecronaca(d.telecronaca!),
        Sezione('Oggi · ${giornoLungo(oggi)}'),
        if (diOggi.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Oggi non ci sono gare né eventi in programma.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          )
        else
          for (final v in diOggi) VoceTile(v),
        if (diOggi.isEmpty && prossimo.isNotEmpty) ...[
          Sezione('Prossimo appuntamento · ${giornoLungo(prossimo.first.data)}'),
          for (final v in prossimo) VoceTile(v),
        ],
        Sezione(
          'I rioni',
          // la mappa vera (Google Maps) con i confini dei rioni, a tutta pagina
          coda: FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaMappa())),
            icon: const IconaTratto('mappa', lato: 18),
            label: const Text('Mappa'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
        const MappaRioni(),
        const _SponsorESocial(),
        const _RegolamentoEModuli(),
      ],
    );
  }
}

/// In fondo alla Home, dopo i social: riquadro oro (il colore del logo) che apre «Regolamento e moduli».
class _RegolamentoEModuli extends StatelessWidget {
  const _RegolamentoEModuli();

  static const _oro = Color(0xFFFEAB06);
  static const _blu = Color(0xFF062246);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      color: _oro,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        leading: const CircleAvatar(
          radius: 24,
          backgroundColor: _blu,
          child: Icon(Icons.description_outlined, color: _oro, size: 26),
        ),
        title: Text('Regolamento e moduli', style: t.textTheme.titleMedium?.copyWith(color: _blu, fontWeight: FontWeight.w800)),
        subtitle: Text('Il regolamento del Palio e i moduli da compilare',
            style: t.textTheme.bodyMedium?.copyWith(color: _blu.withValues(alpha: 0.85))),
        trailing: const Icon(Icons.chevron_right, color: _blu),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaDocumenti())),
      ),
    );
  }
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

/// In fondo alla Home: gli sponsor, se il portale ne pubblica, e le pagine social del Palio.
class _SponsorESocial extends StatefulWidget {
  const _SponsorESocial();

  @override
  State<_SponsorESocial> createState() => _SponsorESocialState();
}

class _SponsorESocialState extends State<_SponsorESocial> {
  final Future<List<Sponsor>> _sponsor = Api.instance.sponsor().catchError((_) => <Sponsor>[]);

  Future<void> _apri(String url) async {
    final avvisi = ScaffoldMessenger.of(context);
    // con l'app Facebook o Instagram installata il link si apre li', altrimenti nel browser
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      avvisi.showSnackBar(const SnackBar(content: Text('Impossibile aprire il collegamento')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FutureBuilder<List<Sponsor>>(
        future: _sponsor,
        builder: (context, s) {
          final lista = s.data ?? const <Sponsor>[];
          if (lista.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Sezione('Sponsor'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: lista.length,
              itemBuilder: (context, i) => LogoSponsor(lista[i]),
            ),
          ]);
        },
      ),
      const Sezione('Seguici sui social'),
      for (final c in _canali)
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: c.icona,
            title: Text(c.nome, style: t.textTheme.titleMedium),
            subtitle: Text(c.dettaglio),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _apri(c.url),
          ),
        ),
    ]);
  }
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
      color: t.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.mic, size: 20, color: t.colorScheme.secondaryContainer),
            const SizedBox(width: 8),
            Text('IL PALIO IN DIRETTA',
                style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.secondaryContainer, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(tc.testo, style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onPrimary, height: 1.4)),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(q, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onPrimary.withValues(alpha: 0.7))),
          ],
        ]),
      ),
    );
  }
}
