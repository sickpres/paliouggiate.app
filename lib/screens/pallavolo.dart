import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';
import '../push.dart';
import '../widgets/comuni.dart';
import '../widgets/griglia_mese.dart';
import '../widgets/icone_tratto.dart';

// il rione scelto nel filtro resta selezionato anche alle aperture successive (chiaveRione, in push.dart),
// e cosi' la vista (mese o elenco completo)
const _kVista = 'vista_pallavolo';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_RIONE=id
const _provaRione = int.fromEnvironment('PROVA_RIONE');

class _Dati {
  final Edizione edizione;
  final CalendarioPartite cal;
  final List<Rione> rioni;
  _Dati(this.edizione, this.cal, this.rioni);
}

Future<_Dati> _carica() async {
  final r = await Future.wait([Api.instance.edizione(), Api.instance.partite('pallavolo'), rioniInCache()]);
  return _Dati(r[0] as Edizione, r[1] as CalendarioPartite, r[2] as List<Rione>);
}

/// Scheda Pallavolo: il calendario delle partite, a mese o in elenco completo, di tutti o di un rione solo.
class PaginaPallavolo extends StatefulWidget {
  const PaginaPallavolo({super.key});

  @override
  State<PaginaPallavolo> createState() => _PaginaPallavoloState();
}

class _PaginaPallavoloState extends State<PaginaPallavolo> {
  int? _rione;
  bool _pronto = false;
  bool _mese = true;
  List<Rione> _rioni = const []; // per il titolo e il filtro

  @override
  void initState() {
    super.initState();
    _leggi();
  }

  Future<void> _leggi() async {
    if (_provaRione > 0) await _scegli(_provaRione);
    try {
      final p = await SharedPreferences.getInstance();
      _rione = p.getInt(chiaveRione);
      _mese = p.getString(_kVista) != 'elenco';
    } catch (_) {
      _rione = null; // senza preferenze si parte da «Tutti»
    }
    try {
      _rioni = await rioniInCache();
    } catch (_) {
      // il titolo resta «Pallavolo»; i rioni arrivano con i dati della pagina
    }
    if (mounted) setState(() => _pronto = true);
  }

  Future<void> _scegli(int? rione) async {
    setState(() => _rione = rione);
    try {
      final p = await SharedPreferences.getInstance();
      if (rione == null) {
        await p.remove(chiaveRione);
      } else {
        await p.setInt(chiaveRione, rione);
      }
    } catch (_) {
      // la scelta vale comunque finche' la pagina resta aperta
    }
  }

  void _cambia() {
    setState(() => _mese = !_mese);
    SharedPreferences.getInstance().then((p) => p.setString(_kVista, _mese ? 'mese' : 'elenco')).catchError((_) => false);
  }

  Future<void> _filtra() async {
    if (_rioni.isEmpty) {
      try {
        _rioni = await rioniInCache(aggiorna: true);
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;
    final o = await scegliFiltro<int>(context, 'Rione', [
      const OpzioneFiltro<int>(null, 'Tutti'),
      for (final r in _rioni) OpzioneFiltro<int>(r.id, r.nome, icona: SegnoRione(rione: r, colore: r.colore, lato: 26)),
    ], _scelto);
    if (o != null && mounted) _scegli(o.valore);
  }

  // un rione salvato che non esiste piu' vale come «Tutti»
  int? get _scelto => _rioni.any((r) => r.id == _rione) ? _rione : null;

  @override
  Widget build(BuildContext context) {
    final sel = _scelto;
    final nome = sel == null ? null : _rioni.firstWhere((r) => r.id == sel).nome;
    return Scaffold(
      appBar: AppBar(
        title: TitoloConFiltro('Pallavolo', nome),
        actions: [
          BottoneFiltra(attivo: sel != null, onPressed: _filtra),
          IconButton(
            tooltip: _mese ? 'Mostra l\'elenco completo' : 'Mostra il calendario del mese',
            onPressed: _cambia,
            icon: IconaTratto(_mese ? 'vista_elenco' : 'vista_mese', lato: 24),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !_pronto
          ? const Center(child: CircularProgressIndicator())
          : DatiRemoti<_Dati>(carica: _carica, costruisci: (context, d) {
              // i rioni arrivati con i dati servono anche al titolo, se all'apertura non c'erano
              if (_rioni.isEmpty && d.rioni.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _rioni = d.rioni);
                });
              }
              final rioni = {for (final r in d.rioni) r.id: r};
              final s = rioni.containsKey(_rione) ? _rione : null;
              return _mese ? _VistaMese(d, rioni, s) : _elenco(context, d, rioni, s);
            }),
    );
  }

  Widget _elenco(BuildContext context, _Dati d, Map<int, Rione> rioni, int? sel) {
    final t = Theme.of(context);
    final partite = sel == null ? d.cal.partite : d.cal.partite.where((p) => p.gioca(sel)).toList();
    final righe = <Widget>[const SizedBox(height: 8)];

    final info = [d.cal.chi, d.cal.luogo, if (d.cal.luogoPioggia.isNotEmpty) 'se piove: ${d.cal.luogoPioggia}'].where((s) => s.isNotEmpty).join(' · ');
    final giocate = d.cal.partite.where((p) => p.risultato.isNotEmpty).length;
    if (giocate > 0) {
      righe.add(Card(
        color: t.colorScheme.secondaryContainer,
        child: ListTile(
          leading: Icon(d.cal.mancanti > 0 ? Icons.timelapse : Icons.flag, color: t.colorScheme.onSecondaryContainer),
          title: Text(d.cal.mancanti > 0 ? 'Risultati provvisori' : 'Tutte le partite sono state giocate'),
          subtitle: Text(d.cal.mancanti > 0
              ? '$giocate ${giocate == 1 ? 'partita giocata' : 'partite giocate'}, ${ancoraDaGiocare(d.cal.mancanti, 'partite')} alla fine della gara.'
              : 'La classifica finale è nella scheda Giochi.'),
        ),
      ));
    }
    if (info.isNotEmpty || sel != null) {
      final delRione = partite.length;
      righe.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(
          [
            if (sel != null) '${rioni[sel]!.nome}: $delRione ${delRione == 1 ? 'partita' : 'partite'}',
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
      righe.add(_PartitaTile(p, rioni, sel));
    }
    righe.add(const SizedBox(height: 24));
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: righe);
  }
}

/// Vista a mese: sopra la griglia dei giorni con un segno per le partite, sotto le partite del giorno scelto.
class _VistaMese extends StatefulWidget {
  final _Dati d;
  final Map<int, Rione> rioni;
  final int? sel;
  const _VistaMese(this.d, this.rioni, this.sel);

  @override
  State<_VistaMese> createState() => _VistaMeseState();
}

class _VistaMeseState extends State<_VistaMese> {
  late DateTime _mese; // primo giorno del mese mostrato
  late DateTime _giorno; // giorno scelto

  List<Partita> get _partite =>
      widget.d.cal.partite.where((p) => p.data != null && (widget.sel == null || p.gioca(widget.sel!))).toList();

  List<Partita> _di(DateTime g) => _partite.where((p) => stessoGiorno(p.data!, g)).toList();

  @override
  void initState() {
    super.initState();
    // il mese delle partite (luglio): da oggi se gioca in questo mese, altrimenti dalla prima partita;
    // senza partite dal primo giorno del Palio
    final date = [for (final p in widget.d.cal.partite) if (p.data != null) p.data!];
    final ini = widget.d.edizione.inizio;
    _giorno = date.isEmpty && ini != null ? GrigliaMese.soloGiorno(ini) : giornoIniziale(date);
    _mese = DateTime(_giorno.year, _giorno.month);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final delGiorno = _di(_giorno);
    final ini = widget.d.edizione.inizio, fine = widget.d.edizione.fine;
    bool utile(DateTime g) => ini != null && fine != null
        ? !g.isBefore(GrigliaMese.soloGiorno(ini)) && !g.isAfter(GrigliaMese.soloGiorno(fine))
        : _di(g).isNotEmpty;
    final senzaData = widget.d.cal.partite.any((p) => p.data == null);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GrigliaMese(
        mese: _mese,
        giorno: _giorno,
        onScegli: (g) => setState(() => _giorno = g),
        quanti: (g) => _di(g).length,
        unita: 'partite',
        utile: utile,
        segni: (g) {
          final n = _di(g).length;
          return n == 0 ? const SizedBox.shrink() : Row(mainAxisSize: MainAxisSize.min, children: [segnoGiorno(t.colorScheme.primary, n)]);
        },
      ),
      Expanded(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Sezione(giornoLungo(_giorno)),
            if (delGiorno.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    widget.d.cal.partite.isEmpty
                        ? 'Il calendario delle partite non è ancora pubblicato.'
                        : widget.sel == null
                            ? 'Nessuna partita in questo giorno.'
                            : '${widget.rioni[widget.sel]!.nome} non gioca in questo giorno.',
                    style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              )
            else
              for (final p in delGiorno) _PartitaTile(p, widget.rioni, widget.sel),
            if (senzaData)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('Alcune partite non hanno ancora una data: sono nell\'elenco completo.',
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    ]);
  }
}

/// Una partita: a sinistra l'orario (e il risultato), a destra i due rioni sullo sfondo «VS», ciascuno con lo stemma
/// grande e il nome sotto. Tema chiaro: bianco e blu (assets/vs.webp); tema scuro: grigio scuro e arancione
/// (assets/vs_scuro.webp), con la scheda dello stesso grigio.
class _PartitaTile extends StatelessWidget {
  final Partita p;
  final Map<int, Rione> rioni;
  final int? sel;
  const _PartitaTile(this.p, this.rioni, this.sel);

  static const _blu = Color(0xFF112658); // il blu dello sfondo «VS»
  static const _grigio = Color(0xFF2A2A2E); // il grigio dello sfondo «VS» scuro
  static const _suArancione = Color(0xFF1C1C1E); // nome sul lato arancione

  Widget _squadra(BuildContext context, int id, Color colore) {
    final r = rioni[id];
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SegnoRione(rione: r, colore: r?.colore ?? '', lato: 64),
      const SizedBox(height: 8),
      Text(r?.nome ?? '?',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colore, height: 1.15, fontWeight: id == sel ? FontWeight.w800 : FontWeight.w600)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final mq = MediaQuery.of(context);
    final scuro = t.brightness == Brightness.dark;
    return Card(
      color: scuro ? _grigio : null,
      surfaceTintColor: Colors.transparent, // nessuna schiaritura: il grigio combacia con lo sfondo «VS»
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: SizedBox(
              width: 56,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.ora.isEmpty ? '--:--' : p.ora,
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                if (p.campo != null) Text('Campo ${p.campo}', style: t.textTheme.bodySmall),
                if (p.risultato.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(p.risultato, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 132),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: ResizeImage(AssetImage(scuro ? 'assets/vs_scuro.webp' : 'assets/vs.webp'), width: (mq.size.width * mq.devicePixelRatio).round()),
                  fit: BoxFit.cover,
                ),
              ),
              child: Row(children: [
                Expanded(child: _squadra(context, p.rioneA, scuro ? Colors.white : _blu)),
                // spazio per la scritta «VS» al centro dello sfondo
                const SizedBox(width: 44),
                Expanded(child: _squadra(context, p.rioneB, scuro ? _suArancione : Colors.white)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
