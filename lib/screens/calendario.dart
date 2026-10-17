import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
import '../widgets/icone_tratto.dart';
import 'pallavolo.dart';

class _Programma {
  final Edizione edizione;
  final List<Voce> voci;
  _Programma(this.edizione, this.voci);
}

Future<_Programma> _carica() async {
  final r = await Future.wait([Api.instance.edizione(), Api.instance.calendario()]);
  return _Programma(r[0] as Edizione, r[1] as List<Voce>);
}

// vista scelta (elenco o mese): resta la stessa alle aperture successive
const _kVista = 'vista_calendario';
// solo per le schermate di prova nel simulatore: --dart-define=PROVA_MESE=true
const _provaMese = bool.fromEnvironment('PROVA_MESE');

class PaginaCalendario extends StatefulWidget {
  const PaginaCalendario({super.key});

  @override
  State<PaginaCalendario> createState() => _PaginaCalendarioState();
}

class _PaginaCalendarioState extends State<PaginaCalendario> {
  bool _mese = _provaMese;

  @override
  void initState() {
    super.initState();
    if (!_provaMese) {
      SharedPreferences.getInstance().then((p) {
        if (mounted && p.getString(_kVista) == 'mese') setState(() => _mese = true);
      }).catchError((_) {});
    }
  }

  void _cambia() {
    setState(() => _mese = !_mese);
    SharedPreferences.getInstance().then((p) => p.setString(_kVista, _mese ? 'mese' : 'elenco')).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            tooltip: _mese ? 'Mostra l\'elenco completo' : 'Mostra il calendario del mese',
            onPressed: _cambia,
            icon: IconaTratto(_mese ? 'vista_elenco' : 'vista_mese', lato: 24),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: DatiRemoti<_Programma>(carica: _carica, costruisci: (context, p) => _mese ? _VistaMese(p) : _Elenco(p)),
    );
  }
}

/// Vista a mese: sopra la griglia dei giorni (con i pallini degli appuntamenti), sotto gli appuntamenti del giorno scelto.
class _VistaMese extends StatefulWidget {
  final _Programma p;
  const _VistaMese(this.p);

  @override
  State<_VistaMese> createState() => _VistaMeseState();
}

class _VistaMeseState extends State<_VistaMese> {
  late DateTime _mese; // primo giorno del mese mostrato
  late DateTime _giorno; // giorno scelto

  static DateTime _soloGiorno(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Voce> _di(DateTime g) => widget.p.voci.where((v) => stessoGiorno(v.data, g)).toList();

  @override
  void initState() {
    super.initState();
    // si parte da oggi se ci sono appuntamenti nel suo mese, altrimenti dal primo giorno con appuntamenti
    final oggi = _soloGiorno(oggiApp());
    final voci = widget.p.voci;
    final nelMese = voci.any((v) => v.data.year == oggi.year && v.data.month == oggi.month);
    final inizio = nelMese || voci.isEmpty ? oggi : _soloGiorno(voci.first.data);
    _giorno = inizio;
    _mese = DateTime(inizio.year, inizio.month);
  }

  void _spostaMese(int n) {
    final m = DateTime(_mese.year, _mese.month + n);
    final conVoci = widget.p.voci.where((v) => v.data.year == m.year && v.data.month == m.month).toList();
    setState(() {
      _mese = m;
      _giorno = conVoci.isEmpty ? m : _soloGiorno(conVoci.first.data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scuro = t.brightness == Brightness.dark;
    final oggi = _soloGiorno(oggiApp());
    final giorniMese = DateTime(_mese.year, _mese.month + 1, 0).day;
    final vuoti = _mese.weekday - 1; // la settimana parte dal lunedi'
    final settimane = ((vuoti + giorniMese) / 7).ceil();
    final delGiorno = _di(_giorno);
    const iniziali = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

    Widget cella(int n) {
      final g = DateTime(_mese.year, _mese.month, n);
      final voci = _di(g);
      final scelto = stessoGiorno(g, _giorno);
      final festivo = g.weekday >= 6;
      final eOggi = stessoGiorno(g, oggi);
      final coloreNumero = scelto
          ? (scuro ? Colors.black : Colors.white)
          : eOggi
              ? t.colorScheme.primary
              : festivo
                  ? t.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                  : t.colorScheme.onSurface;
      return InkResponse(
        onTap: () => setState(() => _giorno = g),
        radius: 26,
        child: Semantics(
          button: true,
          selected: scelto,
          label: '${giornoLungo(g)}${voci.isEmpty ? '' : ', ${voci.length} appuntamenti'}',
          excludeSemantics: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scelto ? (scuro ? Colors.white : t.colorScheme.primary) : null,
              ),
              child: Text('$n',
                  style: t.textTheme.titleLarge?.copyWith(
                      color: coloreNumero, fontWeight: scelto || eOggi ? FontWeight.w700 : FontWeight.w500, fontSize: 20)),
            ),
            const SizedBox(height: 4),
            // un segno per tipo di appuntamento: oro gli eventi, blu i giochi (piu' giochi = trattino)
            SizedBox(
              height: 6,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (voci.any((v) => v.evento)) _segno(t.colorScheme.secondary, 1),
                if (voci.any((v) => v.evento) && voci.any((v) => !v.evento)) const SizedBox(width: 3),
                if (voci.any((v) => !v.evento)) _segno(t.colorScheme.primary, voci.where((v) => !v.evento).length),
              ]),
            ),
          ]),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(children: [
            Expanded(
              child: Text('${mesi[_mese.month - 1][0].toUpperCase()}${mesi[_mese.month - 1].substring(1)} ${_mese.year}',
                  style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton(tooltip: 'Mese precedente', onPressed: () => _spostaMese(-1), icon: const IconaTratto('freccia_sinistra', lato: 26)),
            IconButton(tooltip: 'Mese successivo', onPressed: () => _spostaMese(1), icon: const IconaTratto('freccia_destra', lato: 26)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(iniziali[i],
                      style: t.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600, color: t.colorScheme.onSurfaceVariant.withValues(alpha: i >= 5 ? 0.7 : 1))),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        for (var s = 0; s < settimane; s++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.colorScheme.outlineVariant.withValues(alpha: 0.6), width: 0.6))),
            child: Row(children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Builder(builder: (context) {
                    final n = s * 7 + d - vuoti + 1;
                    return n < 1 || n > giorniMese ? const SizedBox(height: 48) : cella(n);
                  }),
                ),
            ]),
          ),
        Divider(height: 1, thickness: 0.6, color: t.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        Sezione(giornoLungo(_giorno)),
        if (delGiorno.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nessun appuntamento in questo giorno.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          )
        else
          for (final v in delGiorno) VoceTile(v),
      ],
    );
  }

  // pallino per un appuntamento, trattino per piu' appuntamenti dello stesso tipo
  Widget _segno(Color c, int quanti) => Container(
        width: quanti > 1 ? 20 : 6,
        height: 6,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      );
}

class _Elenco extends StatelessWidget {
  final _Programma p;
  const _Elenco(this.p);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final oggi = oggiApp();
    final righe = <Widget>[
      Card(
        color: t.colorScheme.primaryContainer,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          leading: Image.asset('assets/logo.png', width: 64, height: 64),
          title: Text(p.edizione.nome.isEmpty ? 'Palio dei rioni' : p.edizione.nome,
              style: TextStyle(fontWeight: FontWeight.w700, color: t.colorScheme.onPrimaryContainer)),
          subtitle: Text(intervallo(p.edizione.inizio, p.edizione.fine), style: TextStyle(color: t.colorScheme.onPrimaryContainer)),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.sports_volleyball),
          title: const Text('Partite di pallavolo'),
          subtitle: const Text('Tutte le partite, anche solo quelle del tuo rione'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => apriPallavolo(context),
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
      righe.add(VoceTile(v));
    }
    righe.add(const SizedBox(height: 24));
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: righe);
  }
}

void apriPallavolo(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaPallavolo()));

/// Una voce del programma; la pallavolo apre il calendario delle partite.
class VoceTile extends StatelessWidget {
  final Voce v;
  const VoceTile(this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dettagli = [v.chi, v.luogo].where((s) => s.isNotEmpty).join(' · ');
    final partite = v.tipo == 'pallavolo';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: partite ? () => apriPallavolo(context) : null,
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
              child: v.evento
                  ? Icon(Icons.celebration, size: 20, color: t.colorScheme.onTertiaryContainer)
                  : IconaGioco(v.tipo, lato: 20, colore: t.colorScheme.onSecondaryContainer),
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
            if (partite) Icon(Icons.chevron_right, color: t.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
      ),
    );
  }
}
