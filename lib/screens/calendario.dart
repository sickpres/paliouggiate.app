import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
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

// vista scelta (mese, di partenza, o elenco) e filtro per eta': restano gli stessi alle aperture successive
const _kVista = 'vista_calendario';
const _kEta = 'eta_calendario';
// solo per le schermate di prova nel simulatore: --dart-define=PROVA_ELENCO=true
const _provaElenco = bool.fromEnvironment('PROVA_ELENCO');

// filtro per eta': gli eventi restano sempre, perche' valgono per ogni eta'
bool _perEta(Voce v, String? eta) => v.evento || perEta(v.categoria, eta);

class PaginaCalendario extends StatefulWidget {
  const PaginaCalendario({super.key});

  @override
  State<PaginaCalendario> createState() => _PaginaCalendarioState();
}

class _PaginaCalendarioState extends State<PaginaCalendario> {
  bool _mese = !_provaElenco;
  String? _filtro = etaIniziale;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final eta = p.getString(_kEta);
      setState(() {
        if (!_provaElenco && p.getString(_kVista) == 'elenco') _mese = false;
        if (provaEta.isEmpty) _filtro = opzioniEta.any((o) => o.valore == eta) ? eta : null;
      });
    }).catchError((_) {});
  }

  void _cambia() {
    setState(() => _mese = !_mese);
    SharedPreferences.getInstance().then((p) => p.setString(_kVista, _mese ? 'mese' : 'elenco')).catchError((_) => false);
  }

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
            tooltip: _mese ? 'Mostra l\'elenco completo' : 'Mostra il calendario del mese',
            onPressed: _cambia,
            icon: IconaTratto(_mese ? 'vista_elenco' : 'vista_mese', lato: 24),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: DatiRemoti<_Programma>(carica: _carica, costruisci: (context, p) {
        final voci = p.voci.where((v) => _perEta(v, _filtro)).toList();
        return _mese ? _VistaMese(p.edizione, voci) : _Elenco(voci, filtrato: _filtro != null);
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
              for (final v in delGiorno) VoceTile(v),
          ],
        ),
      ),
    ]);
  }
}

class _Elenco extends StatelessWidget {
  final List<Voce> voci;
  final bool filtrato;
  const _Elenco(this.voci, {required this.filtrato});

  @override
  Widget build(BuildContext context) {
    final oggi = oggiApp();
    final righe = <Widget>[];
    if (voci.isEmpty) {
      righe.add(filtrato
          ? const Messaggio(icona: Icons.event_busy, titolo: 'Nessuna gara per questa età')
          : const Messaggio(
              icona: Icons.event_busy,
              titolo: 'Programma non ancora pubblicato',
              testo: 'Le date e gli orari delle gare compariranno qui appena saranno decisi.',
            ));
    }
    DateTime? giorno;
    for (final v in voci) {
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

/// Una voce del programma: un gioco apre la sua pagina, la pallavolo il calendario delle partite.
class VoceTile extends StatelessWidget {
  final Voce v;
  const VoceTile(this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dettagli = [v.chi, v.luogo].where((s) => s.isNotEmpty).join(' · ');
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
            if (apri != null) Icon(Icons.chevron_right, color: t.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
      ),
    );
  }
}
