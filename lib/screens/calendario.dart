import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

class _Programma {
  final Edizione edizione;
  final List<Voce> voci;
  _Programma(this.edizione, this.voci);
}

Future<_Programma> _carica() async {
  final r = await Future.wait([Api.instance.edizione(), Api.instance.calendario()]);
  return _Programma(r[0] as Edizione, r[1] as List<Voce>);
}

class PaginaCalendario extends StatelessWidget {
  const PaginaCalendario({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: DatiRemoti<_Programma>(carica: _carica, costruisci: (context, p) => _Elenco(p)),
    );
  }
}

class _Elenco extends StatelessWidget {
  final _Programma p;
  const _Elenco(this.p);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final oggi = DateTime.now();
    final righe = <Widget>[
      Card(
        color: t.colorScheme.primaryContainer,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: ListTile(
          leading: Icon(Icons.flag, color: t.colorScheme.onPrimaryContainer),
          title: Text(p.edizione.nome.isEmpty ? 'Palio dei rioni' : p.edizione.nome,
              style: TextStyle(fontWeight: FontWeight.w700, color: t.colorScheme.onPrimaryContainer)),
          subtitle: Text(intervallo(p.edizione.inizio, p.edizione.fine), style: TextStyle(color: t.colorScheme.onPrimaryContainer)),
        ),
      ),
    ];
    if (p.voci.isEmpty) {
      righe.add(const Messaggio(
        icona: Icons.event_busy,
        titolo: 'Programma non ancora pubblicato',
        testo: 'Le date e gli orari delle gare compariranno qui appena saranno decisi.',
      ));
    }
    DateTime? giorno;
    for (final v in p.voci) {
      if (giorno == null || !stessoGiorno(giorno, v.data)) {
        giorno = v.data;
        righe.add(Sezione(giornoLungo(v.data),
            coda: stessoGiorno(v.data, oggi) ? Chip(label: const Text('Oggi'), visualDensity: VisualDensity.compact) : null));
      }
      righe.add(_VoceTile(v));
    }
    righe.add(const SizedBox(height: 24));
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: righe);
  }
}

class _VoceTile extends StatelessWidget {
  final Voce v;
  const _VoceTile(this.v);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dettagli = [v.chi, v.luogo].where((s) => s.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Text(v.ora, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: v.evento ? t.colorScheme.tertiaryContainer : t.colorScheme.secondaryContainer,
              child: Icon(v.evento ? Icons.celebration : iconaGioco(v.tipo),
                  size: 20, color: v.evento ? t.colorScheme.onTertiaryContainer : t.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.titolo, style: t.textTheme.titleMedium),
                  if (dettagli.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(dettagli, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    ),
                  if (v.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(v.note, style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
