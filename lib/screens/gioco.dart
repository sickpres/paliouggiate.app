import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
import '../widgets/icone_tratto.dart';
import '../widgets/testo_ricco.dart';
import 'calendario.dart';

// --dart-define=PROVA_TAB_GIOCO=n apre la scheda n del gioco (schermate di prova)
const _provaTab = int.fromEnvironment('PROVA_TAB_GIOCO');

/// Pagina di un gioco con il suo menu in basso: info (data, orario, luogo), classifica, regolamento, criteri, punteggio.
class PaginaGioco extends StatefulWidget {
  final int id;
  final String nome;
  final String tipo;
  const PaginaGioco({super.key, required this.id, required this.nome, required this.tipo});

  @override
  State<PaginaGioco> createState() => _PaginaGiocoState();
}

class _PaginaGiocoState extends State<PaginaGioco> {
  late Future<(SchedaGioco, List<Rione>)> _futuro = _carica();
  SchedaGioco? _gioco; // nome e icona dal portale appena arrivano

  Future<(SchedaGioco, List<Rione>)> _carica() async {
    final r = await Future.wait<Object>([Api.instance.gioco(widget.id), rioniInCache()]);
    final g = r[0] as SchedaGioco;
    if (mounted) setState(() => _gioco = g);
    return (g, r[1] as List<Rione>);
  }

  Future<void> _ricarica() async {
    final f = _carica();
    setState(() => _futuro = f);
    try {
      await f;
    } catch (_) {
      // l'errore lo mostra la pagina
    }
  }

  // menu in basso, come quello principale
  int _scheda = _provaTab.clamp(0, 4);
  static const _voci = [
    VoceMenu('info', 'Info'),
    VoceMenu('classifica_gioco', 'Classifica'),
    VoceMenu('regolamento_gioco', 'Regolamento'),
    VoceMenu('criteri', 'Criteri'),
    VoceMenu('punteggio', 'Punteggio'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          IconaGioco(_gioco?.tipo ?? widget.tipo, lato: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(_gioco?.nome ?? widget.nome, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      bottomNavigationBar: MenuInBasso(scelta: _scheda, onScegli: (i) => setState(() => _scheda = i), voci: _voci),
      body: FutureBuilder<(SchedaGioco, List<Rione>)>(
        future: _futuro,
        builder: (context, s) {
          if (s.hasError) {
            return Messaggio(
              icona: Icons.cloud_off,
              titolo: 'Impossibile caricare il gioco',
              testo: s.error is ApiException ? s.error.toString() : null,
              azione: FilledButton.tonalIcon(onPressed: _ricarica, icon: const Icon(Icons.refresh), label: const Text('Riprova')),
            );
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final (g, rioni) = s.data!;
          final figli = switch (_scheda) {
            0 => _quando(context, g),
            1 => _classifica(context, g, rioni),
            2 => _testo(context, g.regolamento, Icons.menu_book, 'Regolamento non ancora pubblicato'),
            3 => _testo(context, g.criteri, Icons.rule, 'Criteri di valutazione non ancora pubblicati'),
            _ => _punteggio(context, g),
          };
          return RefreshIndicator(
            onRefresh: _ricarica,
            child: ListView(
              key: PageStorageKey(_scheda), // ogni voce ricorda dove era arrivata
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: figli,
            ),
          );
        },
      ),
    );
  }

  List<Widget> _quando(BuildContext context, SchedaGioco g) {
    final t = Theme.of(context);
    return [
      if (g.chi.isNotEmpty || g.luogo.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text([if (g.chi.isNotEmpty) 'Per chi: ${g.chi}', if (g.luogo.isNotEmpty) 'Dove: ${g.luogo}'].join('\n'),
              style: t.textTheme.bodyLarge),
        ),
      if (g.haPartite && g.tipo == 'pallavolo')
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: ListTile(
            leading: const Icon(Icons.sports_volleyball),
            title: const Text('Calendario delle partite'),
            subtitle: const Text('Tutte le partite, anche solo quelle del tuo rione'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => apriPallavolo(context),
          ),
        ),
      if (g.appuntamenti.isEmpty)
        const Messaggio(icona: Icons.event_busy, titolo: 'Date da definire', testo: 'Giorno e orario compariranno qui appena saranno decisi.')
      else ...[
        Sezione(g.appuntamenti.length == 1 ? 'Appuntamento' : '${g.appuntamenti.length} appuntamenti'),
        for (final a in g.appuntamenti)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: t.colorScheme.secondaryContainer,
                child: Text('${a.data.day}', style: TextStyle(fontWeight: FontWeight.w800, color: t.colorScheme.onSecondaryContainer)),
              ),
              title: Text('${giornoLungo(a.data)}${a.ora.isNotEmpty ? ', ore ${a.ora}' : ''}'),
              subtitle: Text([a.luogo, a.chi, a.note].where((x) => x.isNotEmpty).join(' · ')),
            ),
          ),
      ],
    ];
  }

  List<Widget> _classifica(BuildContext context, SchedaGioco g, List<Rione> rioni) {
    final t = Theme.of(context);
    final c = g.classifica;
    if (c == null) {
      return const [
        Messaggio(icona: Icons.leaderboard, titolo: 'Classifica non ancora disponibile', testo: 'Comparirà qui appena verrà inserito il primo risultato.'),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          c.definitiva
              ? 'Classifica finale, con i punti assegnati per il Palio.'
              : c.mancanti > 0
                  ? 'Classifica provvisoria: ${ancoraDaGiocare(c.mancanti, c.unita)} alla fine della gara. I punti del Palio si assegnano a gara conclusa.'
                  : 'Classifica provvisoria: tutti i risultati sono inseriti, si attende la conferma.',
          style: t.textTheme.bodyMedium?.copyWith(fontStyle: c.definitiva ? null : FontStyle.italic),
        ),
      ),
      Card(
        child: Column(children: [
          for (final p in c.righe)
            ListTile(
              leading: SizedBox(
                width: 76,
                child: Row(children: [
                  SizedBox(width: 34, child: Text('${p.posizione}°', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  SegnoRione(rione: rionePerNome(rioni, p.nome), colore: p.colore),
                ]),
              ),
              title: Text(p.nome),
              subtitle: p.dettaglio.isEmpty ? null : Text(p.dettaglio),
              trailing: p.punti == null ? null : Text('${p.punti} pt', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
      for (final gr in c.dettaglio.where((x) => x.righe.isNotEmpty)) ...[
        Sezione(gr.gruppo),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final r in gr.righe) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $r')),
            ]),
          ),
        ),
      ],
    ];
  }

  List<Widget> _testo(BuildContext context, String testo, IconData icona, String vuoto) {
    if (testo.trim().isEmpty || testo.trim() == '<p></p>') {
      return [Messaggio(icona: icona, titolo: vuoto, testo: 'Sarà pubblicato qui appena pronto.')];
    }
    return [
      Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Padding(padding: const EdgeInsets.all(16), child: TestoRicco(testo)),
      ),
    ];
  }

  List<Widget> _punteggio(BuildContext context, SchedaGioco g) {
    final t = Theme.of(context);
    if (g.puntiPosizioni.isEmpty) {
      return const [Messaggio(icona: Icons.emoji_events, titolo: 'Punteggio non ancora definito')];
    }
    const medaglie = [Color(0xFFD4A017), Color(0xFF9EA7AD), Color(0xFFB0703C)];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Punti per la classifica generale del Palio, in base alla posizione nella classifica di questo gioco.',
            style: t.textTheme.bodyMedium),
      ),
      Card(
        child: Column(children: [
          for (var i = 0; i < g.puntiPosizioni.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: i < 3 ? medaglie[i] : t.colorScheme.surfaceContainerHighest,
                foregroundColor: i < 3 ? Colors.white : t.colorScheme.onSurface,
                child: Text('${i + 1}°', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text('${i + 1}° classificato'),
              trailing: Text('${g.puntiPosizioni[i]} punti', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    ];
  }
}
