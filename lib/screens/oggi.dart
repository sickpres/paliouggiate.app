import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
import '../widgets/icone_tratto.dart';
import '../widgets/mappa.dart';
import 'mappa.dart';
import 'calendario.dart';

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
    // senza barra in alto: il logo apre la pagina; ora e batteria scure sull'azzurro
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: DatiRemoti<_Dati>(carica: _carica, costruisci: (context, d) => _Contenuto(d)),
        ),
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
      Future.delayed(const Duration(seconds: 3), () {
        if (scorri.hasClients) scorri.jumpTo(scorri.position.maxScrollExtent);
      });
    }
    return ListView(
      controller: scorri,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 12),
        Image.asset('assets/logo.png', height: 150),
        const SizedBox(height: 12),
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
      ],
    );
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
