import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

/// Un gioco del programma: le sue date e, se pubblicata, la sua classifica.
class _Scheda {
  final String nome;
  final String tipo;
  final List<Voce> sessioni;
  final Gioco? risultati;
  _Scheda(this.nome, this.tipo, this.sessioni, this.risultati);
}

class _Dati {
  final List<_Scheda> schede;
  final List<Rione> rioni;
  _Dati(this.schede, this.rioni);
}

Future<_Dati> _carica() async {
  final r = await Future.wait([Api.instance.giochi(), Api.instance.calendario(), rioniInCache()]);
  final pubblicati = r[0] as List<Gioco>;
  final voci = (r[1] as List<Voce>).where((v) => !v.evento && v.giocoId != null);
  final perGioco = <int, List<Voce>>{};
  for (final v in voci) {
    perGioco.putIfAbsent(v.giocoId!, () => []).add(v);
  }
  final schede = <_Scheda>[];
  for (final g in pubblicati) {
    schede.add(_Scheda(g.nome, g.tipo, perGioco.remove(g.id) ?? const [], g));
  }
  perGioco.forEach((_, s) => schede.add(_Scheda(s.first.titolo, s.first.tipo, s, null)));
  // prima i giochi con i risultati, poi gli altri in ordine di data
  schede.sort((a, b) {
    if ((a.risultati == null) != (b.risultati == null)) return a.risultati != null ? -1 : 1;
    final da = a.sessioni.isEmpty ? DateTime(9999) : a.sessioni.first.data;
    final db = b.sessioni.isEmpty ? DateTime(9999) : b.sessioni.first.data;
    return da.compareTo(db);
  });
  return _Dati(schede, r[2] as List<Rione>);
}

class PaginaGiochi extends StatelessWidget {
  const PaginaGiochi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giochi')),
      body: DatiRemoti<_Dati>(
        carica: _carica,
        costruisci: (context, d) {
          if (d.schede.isEmpty) {
            return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
              Messaggio(icona: Icons.sports, titolo: 'Nessun gioco in programma', testo: 'I giochi dell\'edizione compariranno qui.'),
            ]);
          }
          final conRisultati = d.schede.where((s) => s.risultati != null).length;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (conRisultati == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('I risultati di ogni gioco compariranno qui appena saranno pubblicati.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              for (final s in d.schede) _SchedaGioco(s, d.rioni),
            ],
          );
        },
      ),
    );
  }
}

class _SchedaGioco extends StatelessWidget {
  final _Scheda s;
  final List<Rione> rioni;
  const _SchedaGioco(this.s, this.rioni);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final g = s.risultati;
    final quando = s.sessioni.isNotEmpty
        ? (s.sessioni.length == 1
            ? '${giornoLungo(s.sessioni.first.data)}, ore ${s.sessioni.first.ora}'
            : '${s.sessioni.length} appuntamenti, dal ${giornoLungo(s.sessioni.first.data).toLowerCase()}')
        : intervallo(g?.dataInizio, g?.dataFine);
    final chi = s.sessioni.isNotEmpty ? s.sessioni.first.chi : (g?.chi ?? '');
    final dove = s.sessioni.isNotEmpty ? s.sessioni.first.luogo : (g?.luogo ?? '');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: t.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: g != null ? t.colorScheme.primaryContainer : t.colorScheme.surfaceContainerHighest,
            child: Icon(iconaGioco(s.tipo), color: g != null ? t.colorScheme.onPrimaryContainer : t.colorScheme.onSurfaceVariant),
          ),
          title: Text(s.nome, style: t.textTheme.titleMedium),
          subtitle: Text([quando, if (chi.isNotEmpty) chi].where((x) => x.isNotEmpty).join(' · ')),
          trailing: g != null ? Chip(label: const Text('Risultati'), visualDensity: VisualDensity.compact) : null,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dove.isNotEmpty) _Riga(Icons.place_outlined, dove),
            if (s.sessioni.length > 1)
              for (final v in s.sessioni)
                _Riga(Icons.schedule, '${giornoLungo(v.data)}, ore ${v.ora}${v.note.isNotEmpty ? ' · ${v.note}' : ''}'),
            if (g == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Classifica non ancora pubblicata.', style: t.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
              )
            else ...[
              const SizedBox(height: 8),
              Text('Classifica', style: t.textTheme.titleSmall),
              for (final p in g.classifica)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: SizedBox(
                    width: 68,
                    child: Row(children: [
                      SizedBox(width: 30, child: Text('${p.posizione}°', style: const TextStyle(fontWeight: FontWeight.w800))),
                      SegnoRione(rione: rionePerNome(rioni, p.nome), colore: p.colore, lato: 30),
                    ]),
                  ),
                  title: Text(p.nome),
                  subtitle: p.dettaglio.isEmpty ? null : Text(p.dettaglio),
                  trailing: Text('${p.punti} pt', style: t.textTheme.titleSmall),
                ),
              for (final gr in g.dettaglio.where((x) => x.righe.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Text(gr.gruppo, style: t.textTheme.titleSmall),
                for (final r in gr.righe) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $r')),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  final IconData icona;
  final String testo;
  const _Riga(this.icona, this.testo);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icona, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(testo)),
        ]),
      );
}
