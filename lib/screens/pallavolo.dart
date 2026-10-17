import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

// rione scelto nel filtro: resta selezionato anche alle aperture successive
const _kRione = 'rione_pallavolo';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_RIONE=id
const _provaRione = int.fromEnvironment('PROVA_RIONE');

class _Dati {
  final CalendarioPartite cal;
  final List<Rione> rioni;
  _Dati(this.cal, this.rioni);
}

Future<_Dati> _carica() async {
  final r = await Future.wait([Api.instance.partite('pallavolo'), rioniInCache()]);
  return _Dati(r[0] as CalendarioPartite, r[1] as List<Rione>);
}

class PaginaPallavolo extends StatefulWidget {
  const PaginaPallavolo({super.key});

  @override
  State<PaginaPallavolo> createState() => _PaginaPallavoloState();
}

class _PaginaPallavoloState extends State<PaginaPallavolo> {
  int? _rione;
  bool _pronto = false;
  // per portare in vista il rione scelto nella fila dei filtri
  final _chiavi = <int, GlobalKey>{};
  int? _inVista;

  @override
  void initState() {
    super.initState();
    _leggiRione();
  }

  Future<void> _leggiRione() async {
    if (_provaRione > 0) await _scegli(_provaRione);
    try {
      final p = await SharedPreferences.getInstance();
      _rione = p.getInt(_kRione);
    } catch (_) {
      _rione = null; // senza preferenze si parte da «Tutti»
    }
    if (mounted) setState(() => _pronto = true);
  }

  Future<void> _scegli(int? rione) async {
    setState(() => _rione = rione);
    try {
      final p = await SharedPreferences.getInstance();
      if (rione == null) {
        await p.remove(_kRione);
      } else {
        await p.setInt(_kRione, rione);
      }
    } catch (_) {
      // la scelta vale comunque finche' la pagina resta aperta
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partite di pallavolo')),
      body: !_pronto
          ? const Center(child: CircularProgressIndicator())
          : DatiRemoti<_Dati>(carica: _carica, costruisci: _elenco),
    );
  }

  Widget _elenco(BuildContext context, _Dati d) {
    final t = Theme.of(context);
    final rioni = {for (final r in d.rioni) r.id: r};
    // un rione salvato che non esiste piu' vale come «Tutti»
    final sel = rioni.containsKey(_rione) ? _rione : null;
    if (sel != null && sel != _inVista) {
      _inVista = sel;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _chiavi[sel]?.currentContext;
        if (c != null) Scrollable.ensureVisible(c, alignment: 0.5, duration: const Duration(milliseconds: 250));
      });
    }
    final partite = sel == null ? d.cal.partite : d.cal.partite.where((p) => p.gioca(sel) || p.arbitro == sel).toList();

    final righe = <Widget>[
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: const Text('Tutti'), selected: sel == null, onSelected: (_) => _scegli(null)),
            ),
            for (final r in d.rioni)
              Padding(
                key: _chiavi.putIfAbsent(r.id, GlobalKey.new),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  avatar: SegnoRione(rione: r, colore: r.colore, lato: 22),
                  label: Text(r.nome),
                  selected: sel == r.id,
                  showCheckmark: false,
                  onSelected: (_) => _scegli(sel == r.id ? null : r.id),
                ),
              ),
          ],
        ),
      ),
    ];

    final info = [d.cal.chi, d.cal.luogo].where((s) => s.isNotEmpty).join(' · ');
    if (info.isNotEmpty || sel != null) {
      final giocate = sel == null ? 0 : partite.where((p) => p.gioca(sel)).length;
      final arbitrate = sel == null ? 0 : partite.where((p) => p.arbitro == sel).length;
      righe.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(
          [
            if (sel != null) '${rioni[sel]!.nome}: $giocate ${giocate == 1 ? 'partita' : 'partite'}'
                '${arbitrate > 0 ? ', $arbitrate da arbitrare' : ''}',
            if (info.isNotEmpty) info,
          ].join('\n'),
          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      ));
    }

    if (partite.isEmpty) {
      righe.add(Messaggio(
        icona: Icons.sports_volleyball,
        titolo: d.cal.partite.isEmpty ? 'Calendario non ancora pubblicato' : 'Nessuna partita per questo rione',
        testo: d.cal.partite.isEmpty ? 'Le partite di pallavolo compariranno qui appena saranno stabilite.' : null,
      ));
    }

    String? giorno;
    for (final p in partite) {
      final g = p.data == null ? 'Data da definire' : giornoLungo(p.data!);
      if (g != giorno) {
        giorno = g;
        righe.add(Sezione(g, coda: p.data != null && stessoGiorno(p.data!, oggiApp()) ? const Chip(label: Text('Oggi'), visualDensity: VisualDensity.compact) : null));
      }
      righe.add(_PartitaTile(p, rioni, sel, d.cal.arbitri));
    }
    righe.add(const SizedBox(height: 24));
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: righe);
  }
}

class _PartitaTile extends StatelessWidget {
  final Partita p;
  final Map<int, Rione> rioni;
  final int? sel;
  final bool arbitri;
  const _PartitaTile(this.p, this.rioni, this.sel, this.arbitri);

  Widget _squadra(BuildContext context, int id) {
    final r = rioni[id];
    final mio = id == sel;
    return Row(children: [
      SegnoRione(rione: r, colore: r?.colore ?? '', lato: 26),
      const SizedBox(width: 8),
      Expanded(
        child: Text(r?.nome ?? '?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: mio ? FontWeight.w800 : FontWeight.w400)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final arbitro = p.arbitro == null ? null : rioni[p.arbitro];
    final arbitraSel = sel != null && p.arbitro == sel;
    return Card(
      color: arbitraSel ? t.colorScheme.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 60,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.ora.isEmpty ? '--:--' : p.ora,
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
              if (p.campo != null) Text('Campo ${p.campo}', style: t.textTheme.bodySmall),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _squadra(context, p.rioneA),
              const SizedBox(height: 6),
              _squadra(context, p.rioneB),
              if (arbitri && arbitro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Arbitra ${arbitro.nome}',
                      style: t.textTheme.bodySmall?.copyWith(
                          fontWeight: arbitraSel ? FontWeight.w800 : FontWeight.w400,
                          color: arbitraSel ? t.colorScheme.onTertiaryContainer : t.colorScheme.onSurfaceVariant)),
                ),
            ]),
          ),
          if (p.risultato.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 14),
              child: Text(p.risultato, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}
