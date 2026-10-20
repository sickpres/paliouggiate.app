import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';
import '../tema.dart';
import '../widgets/comuni.dart';
import '../widgets/foto_gioco.dart';
import '../widgets/griglia_mese.dart';
import '../widgets/icone_tratto.dart';
import 'gioco.dart';
import 'home.dart';

class _Programma {
  final Edizione edizione;
  final List<Voce> voci;
  _Programma(this.edizione, this.voci);
}

Future<_Programma> _carica() async {
  final r = await Future.wait([Api.instance.edizione(), Api.instance.calendario()]);
  return _Programma(r[0] as Edizione, r[1] as List<Voce>);
}

// filtro per eta': resta lo stesso alle aperture successive. La vista invece parte sempre dal programma con le foto;
// il calendario del mese si apre dal pulsante in alto
const _kEta = 'eta_calendario';
// solo per le schermate di prova nel simulatore: --dart-define=PROVA_MESE=true apre il calendario del mese
const _provaMese = bool.fromEnvironment('PROVA_MESE');

// filtro per eta': con un'eta' scelta restano solo i giochi di quella categoria; i giochi «per tutti»
// e gli eventi si vedono solo con «Tutti» (nessun filtro)
bool _perEta(Voce v, String? eta) => eta == null || (!v.evento && perEta(v.categoria, eta));

class PaginaCalendario extends StatefulWidget {
  const PaginaCalendario({super.key});

  @override
  State<PaginaCalendario> createState() => _PaginaCalendarioState();
}

class _PaginaCalendarioState extends State<PaginaCalendario> {
  bool _mese = _provaMese;
  String? _filtro = etaIniziale;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final eta = p.getString(_kEta);
      if (provaEta.isEmpty) setState(() => _filtro = opzioniEta.any((o) => o.valore == eta) ? eta : null);
    }).catchError((_) {});
  }

  void _cambia() => setState(() => _mese = !_mese);

  Future<void> _filtra() async {
    final o = await scegliFiltro(context, 'Gare per età', opzioniEta, _filtro);
    if (o == null || !mounted) return;
    setState(() => _filtro = o.valore);
    SharedPreferences.getInstance()
        .then((p) => o.valore == null ? p.remove(_kEta) : p.setString(_kEta, o.valore!))
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titoloConEta('Calendario', _filtro)),
        actions: [
          BottoneFiltra(attivo: _filtro != null, onPressed: _filtra),
          IconButton(
            tooltip: _mese ? 'Mostra il programma' : 'Mostra il calendario del mese',
            onPressed: _cambia,
            icon: IconaTratto(_mese ? 'vista_elenco' : 'vista_mese', lato: 24),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: DatiRemoti<_Programma>(carica: _carica, costruisci: (context, p) {
        final voci = p.voci.where((v) => _perEta(v, _filtro)).toList();
        return _mese ? _VistaMese(p.edizione, voci) : _VistaProgramma(voci, filtrato: _filtro != null);
      }),
    );
  }
}

/// Vista a mese: sopra la griglia dei giorni (con i pallini degli appuntamenti), sotto gli appuntamenti del giorno scelto.
class _VistaMese extends StatefulWidget {
  final Edizione edizione;
  final List<Voce> voci;
  const _VistaMese(this.edizione, this.voci);

  @override
  State<_VistaMese> createState() => _VistaMeseState();
}

class _VistaMeseState extends State<_VistaMese> {
  late DateTime _mese; // primo giorno del mese mostrato
  late DateTime _giorno; // giorno scelto

  List<Voce> _di(DateTime g) => widget.voci.where((v) => stessoGiorno(v.data, g)).toList();

  @override
  void initState() {
    super.initState();
    // si parte da oggi se ci sono appuntamenti nel suo mese, altrimenti dal primo giorno con appuntamenti
    _giorno = giornoIniziale([for (final v in widget.voci) v.data]);
    _mese = DateTime(_giorno.year, _giorno.month);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final delGiorno = _di(_giorno);
    // solo le settimane con giorni del Palio (o, senza date dell'edizione, con appuntamenti)
    final ini = widget.edizione.inizio, fine = widget.edizione.fine;
    bool utile(DateTime g) => ini != null && fine != null
        ? !g.isBefore(GrigliaMese.soloGiorno(ini)) && !g.isAfter(GrigliaMese.soloGiorno(fine))
        : _di(g).isNotEmpty;

    // il calendario resta fermo: scorrono solo gli appuntamenti del giorno, sotto
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GrigliaMese(
        mese: _mese,
        giorno: _giorno,
        onScegli: (g) => setState(() => _giorno = g),
        quanti: (g) => _di(g).length,
        unita: 'appuntamenti',
        utile: utile,
        // un segno per tipo di appuntamento: oro gli eventi, blu i giochi (piu' giochi = trattino)
        segni: (g) {
          final voci = _di(g);
          final eventi = voci.any((v) => v.evento), giochi = voci.where((v) => !v.evento).length;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (eventi) segnoGiorno(t.colorScheme.secondary, 1),
            if (eventi && giochi > 0) const SizedBox(width: 3),
            if (giochi > 0) segnoGiorno(t.colorScheme.primary, giochi),
          ]);
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
                child: Text('Nessun appuntamento in questo giorno.',
                    style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              )
            else
              for (final v in delGiorno) SchedaVoce(v),
          ],
        ),
      ),
    ]);
  }
}

const _giorniBrevi = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

/// Vista di partenza: in alto i giorni del programma da scegliere («Tutti» o uno solo), sotto gli appuntamenti
/// in schede con la foto del gioco.
class _VistaProgramma extends StatefulWidget {
  final List<Voce> voci;
  final bool filtrato;
  const _VistaProgramma(this.voci, {required this.filtrato});

  @override
  State<_VistaProgramma> createState() => _VistaProgrammaState();
}

class _VistaProgrammaState extends State<_VistaProgramma> {
  DateTime? _giorno; // null = tutti i giorni

  List<DateTime> get _giorni {
    final g = <DateTime>[];
    for (final v in widget.voci) {
      final d = DateTime(v.data.year, v.data.month, v.data.day);
      if (g.isEmpty || g.last != d) g.add(d);
    }
    return g;
  }

  @override
  void initState() {
    super.initState();
    // nei giorni del Palio si parte da oggi, altrimenti da «Tutti»
    final oggi = oggiApp();
    for (final g in _giorni) {
      if (stessoGiorno(g, oggi)) _giorno = g;
    }
  }

  @override
  Widget build(BuildContext context) {
    final giorni = _giorni;
    // il giorno scelto puo' sparire cambiando il filtro per eta': allora si torna a «Tutti»
    final scelto = giorni.any((g) => g == _giorno) ? _giorno : null;
    final voci = scelto == null ? widget.voci : widget.voci.where((v) => stessoGiorno(v.data, scelto)).toList();
    final oggi = oggiApp();

    final righe = <Widget>[];
    if (widget.voci.isEmpty) {
      righe.add(widget.filtrato
          ? const Messaggio(icona: Icons.event_busy, titolo: 'Nessuna gara per questa età')
          : const Messaggio(
              icona: Icons.event_busy,
              titolo: 'Programma non ancora pubblicato',
              testo: 'Le date e gli orari delle gare compariranno qui appena saranno decisi.',
            ));
    }
    DateTime? giorno;
    for (final v in voci) {
      // con «Tutti» un'intestazione per giorno; con un giorno solo il giorno e' gia' nel filtro
      if (scelto == null && (giorno == null || !stessoGiorno(giorno, v.data))) {
        giorno = v.data;
        righe.add(Sezione(giornoLungo(v.data),
            coda: stessoGiorno(v.data, oggi) ? Chip(label: const Text('Oggi'), visualDensity: VisualDensity.compact) : null));
      }
      righe.add(SchedaVoce(v));
    }
    righe.add(const SizedBox(height: 24));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (giorni.isNotEmpty)
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            children: [
              _ChipGiorno('Tutti', scelto == null, () => setState(() => _giorno = null)),
              for (final g in giorni)
                _ChipGiorno('${_giorniBrevi[g.weekday - 1]} ${g.day}', scelto == g, () => setState(() => _giorno = g)),
            ],
          ),
        ),
      Expanded(child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: righe)),
    ]);
  }
}

/// Giorno da scegliere in alto nel programma: pillola oro se scelto, chiara altrimenti.
class _ChipGiorno extends StatelessWidget {
  final String testo;
  final bool scelto;
  final VoidCallback onTap;
  const _ChipGiorno(this.testo, this.scelto, this.onTap);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: scelto,
        child: Material(
          color: scelto ? oro : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(testo,
                    style: t.textTheme.titleSmall?.copyWith(
                        color: scelto ? bluNotte : t.colorScheme.onSurface, fontWeight: scelto ? FontWeight.w800 : FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Appuntamento del programma in una scheda con la foto del gioco a sinistra (FotoGioco).
class SchedaVoce extends StatelessWidget {
  final Voce v;
  const SchedaVoce(this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final partite = v.tipo == 'pallavolo';
    final gioco = !v.evento && v.giocoId != null && !partite;
    final apri = partite
        ? () => apriPallavolo(context)
        : gioco
            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaginaGioco(id: v.giocoId!, nome: v.titolo, tipo: v.tipo)))
            : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: apri,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            FotoGioco(giocoId: v.giocoId, tipo: v.tipo, evento: v.evento),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (v.ora.isNotEmpty)
                  Text(v.ora,
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
                Text(v.titolo, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                if (v.luogo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(v.luogo, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ),
                if (v.chi.isNotEmpty && v.chi != 'Tutti')
                  Text(v.chi, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                if (v.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(v.note, style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ),
              ]),
            ),
            if (apri != null) Icon(Icons.chevron_right, color: t.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
