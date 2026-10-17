import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
import 'calendario.dart';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_TELECRONACA="testo"
const _provaTelecronaca = String.fromEnvironment('PROVA_TELECRONACA');

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
    return Scaffold(
      appBar: AppBar(title: const Text('Palio Uggiate con Ronago')),
      body: DatiRemoti<_Dati>(carica: _carica, costruisci: (context, d) => _Contenuto(d)),
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 12),
        Image.asset('assets/logo.png', height: 150),
        const SizedBox(height: 12),
        if (d.edizione.nome.isNotEmpty)
          Text(d.edizione.nome, textAlign: TextAlign.center, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(intervallo(d.edizione.inizio, d.edizione.fine),
            textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        if (stato != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.flag, size: 18),
                label: Text(stato),
                backgroundColor: t.colorScheme.primaryContainer,
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
    return stessoGiorno(c, DateTime.now()) ? 'Aggiornata oggi alle $ora' : 'Aggiornata ${giornoLungo(c).toLowerCase()} alle $ora';
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
          const SizedBox(height: 8),
          Text([if (q.isNotEmpty) q, "testo scritto dall'IA"].join(' · '),
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onPrimary.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}
