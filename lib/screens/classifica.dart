import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

class _Dati {
  final Edizione edizione;
  final ClassificaDettaglio classifica;
  final List<AnnoArchivio> archivio;
  final List<Rione> rioni;
  _Dati(this.edizione, this.classifica, this.archivio, this.rioni);
}

Future<_Dati> _carica() async {
  final r = await Future.wait([
    Api.instance.edizione(),
    Api.instance.classifica(),
    Api.instance.archivio(),
    rioniInCache(aggiorna: true),
  ]);
  return _Dati(r[0] as Edizione, r[1] as ClassificaDettaglio, r[2] as List<AnnoArchivio>, r[3] as List<Rione>);
}

class PaginaClassifica extends StatefulWidget {
  const PaginaClassifica({super.key});

  @override
  State<PaginaClassifica> createState() => _PaginaClassificaState();
}

class _PaginaClassificaState extends State<PaginaClassifica> {
  bool _albo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classifica')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Edizione in corso'), icon: Icon(Icons.leaderboard)),
                ButtonSegment(value: true, label: Text('Albo d\'oro'), icon: Icon(Icons.history)),
              ],
              selected: {_albo},
              onSelectionChanged: (s) => setState(() => _albo = s.first),
            ),
          ),
          Expanded(
            child: DatiRemoti<_Dati>(
              carica: _carica,
              costruisci: (context, d) => _albo ? _Albo(d) : _Generale(d),
            ),
          ),
        ],
      ),
    );
  }
}

/// Posizioni con gli ex aequo: a parita' di punti stessa posizione.
List<int> _posizioni(List<int> punti) {
  final out = <int>[];
  for (var i = 0; i < punti.length; i++) {
    out.add(i > 0 && punti[i] == punti[i - 1] ? out[i - 1] : i + 1);
  }
  return out;
}

class _Generale extends StatelessWidget {
  final _Dati d;
  const _Generale(this.d);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = d.classifica;
    final pos = _posizioni([for (final r in c.righe) r.punti]);
    final nomiGiochi = {for (final g in c.giochi) g.id: g.nome};
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Sezione(d.edizione.nome.isEmpty ? 'Classifica generale' : 'Classifica generale · ${d.edizione.nome}'),
        for (var i = 0; i < c.righe.length; i++)
          Card(
            child: Theme(
              data: t.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                enabled: c.righe[i].perGioco.isNotEmpty,
                leading: SizedBox(
                  width: 76,
                  child: Row(children: [
                    SizedBox(
                      width: 32,
                      child: Text(c.iniziata ? '${pos[i]}°' : '–',
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    SegnoRione(rione: _rione(c.righe[i].id), colore: c.righe[i].colore, lato: 40),
                  ]),
                ),
                title: Text(c.righe[i].nome, style: t.textTheme.titleMedium),
                trailing: Text('${c.righe[i].punti}', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                children: [
                  for (final e in c.righe[i].perGioco.entries)
                    ListTile(
                      dense: true,
                      title: Text(nomiGiochi[e.key] ?? 'Altri punti'),
                      trailing: Text('${e.value}'),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Rione? _rione(int id) {
    for (final r in d.rioni) {
      if (r.id == id) return r;
    }
    return null;
  }
}

class _Albo extends StatelessWidget {
  final _Dati d;
  const _Albo(this.d);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (d.archivio.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
        Messaggio(icona: Icons.history, titolo: 'Nessuna edizione passata', testo: 'Le classifiche delle edizioni concluse compariranno qui.'),
      ]);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final a in d.archivio) ...[
          Sezione('Palio ${a.anno}'),
          Card(
            child: Column(children: [
              for (final p in a.classifica)
                ListTile(
                  leading: SizedBox(
                    width: 76,
                    child: Row(children: [
                      SizedBox(
                        width: 32,
                        child: p.posizione == 1
                            ? const Icon(Icons.emoji_events, color: Color(0xFFD4A017))
                            : Text('${p.posizione}°', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      SegnoRione(rione: rionePerNome(d.rioni, p.nome), colore: p.colore),
                    ]),
                  ),
                  title: Text(p.nome),
                  trailing: Text('${p.punti}', style: t.textTheme.titleMedium),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
