import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
import 'gioco.dart';

// --dart-define=PROVA_CERCA=testo scrive nel campo di ricerca; PROVA_GIOCO=id apre la pagina del gioco (schermate di prova)
const _provaCerca = String.fromEnvironment('PROVA_CERCA');
const _provaGioco = int.fromEnvironment('PROVA_GIOCO');

/// Un gioco del programma: le sue date e, se c'e', la sua classifica (definitiva o provvisoria).
class _Scheda {
  final int id;
  final String nome;
  final String tipo;
  final List<Voce> sessioni;
  final Gioco? risultati;
  _Scheda(this.id, this.nome, this.tipo, this.sessioni, this.risultati);

  String get chi => sessioni.isNotEmpty ? sessioni.first.chi : (risultati?.chi ?? '');
}

Future<List<_Scheda>> _carica() async {
  final r = await Future.wait([Api.instance.giochi(), Api.instance.calendario()]);
  final pubblicati = r[0] as List<Gioco>;
  final voci = (r[1] as List<Voce>).where((v) => !v.evento && v.giocoId != null);
  final perGioco = <int, List<Voce>>{};
  for (final v in voci) {
    perGioco.putIfAbsent(v.giocoId!, () => []).add(v);
  }
  final schede = <_Scheda>[];
  for (final g in pubblicati) {
    schede.add(_Scheda(g.id, g.nome, g.tipo, perGioco.remove(g.id) ?? const [], g));
  }
  perGioco.forEach((id, s) => schede.add(_Scheda(id, s.first.titolo, s.first.tipo, s, null)));
  // prima i giochi conclusi, poi quelli in corso, poi gli altri; a parita' in ordine di data
  int peso(_Scheda s) => s.risultati == null ? 2 : (s.risultati!.parziale ? 1 : 0);
  schede.sort((a, b) {
    if (peso(a) != peso(b)) return peso(a) - peso(b);
    final da = a.sessioni.isEmpty ? DateTime(9999) : a.sessioni.first.data;
    final db = b.sessioni.isEmpty ? DateTime(9999) : b.sessioni.first.data;
    return da.compareTo(db);
  });
  return schede;
}

// ricerca senza badare a maiuscole e accenti, parola per parola
String _semplice(String s) {
  const da = 'àáâäèéêëìíîïòóôöùúûü';
  const a = 'aaaaeeeeiiiioooouuuu';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = da.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b.toString();
}

bool _trova(_Scheda s, String cerca) {
  final dove = _semplice('${s.nome} ${s.chi} ${s.tipo.replaceAll('_', ' ')}');
  return _semplice(cerca).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).every(dove.contains);
}

class PaginaGiochi extends StatefulWidget {
  const PaginaGiochi({super.key});

  @override
  State<PaginaGiochi> createState() => _PaginaGiochiState();
}

class _PaginaGiochiState extends State<PaginaGiochi> {
  final _cerca = TextEditingController(text: _provaCerca);

  @override
  void initState() {
    super.initState();
    if (_provaGioco > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PaginaGioco(id: _provaGioco, nome: 'Gioco', tipo: ''))));
    }
  }

  @override
  void dispose() {
    _cerca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Giochi')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _cerca,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cerca un gioco',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _cerca.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Cancella la ricerca',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_cerca.clear),
                    ),
              filled: true,
              fillColor: t.colorScheme.surfaceContainerLowest,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: DatiRemoti<List<_Scheda>>(
            carica: _carica,
            costruisci: (context, tutte) {
              if (tutte.isEmpty) {
                return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                  Messaggio(icona: Icons.sports, titolo: 'Nessun gioco in programma', testo: 'I giochi dell\'edizione compariranno qui.'),
                ]);
              }
              final schede = tutte.where((s) => _trova(s, _cerca.text)).toList();
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  if (schede.isEmpty)
                    Messaggio(icona: Icons.search_off, titolo: 'Nessun gioco trovato', testo: 'Nessun gioco corrisponde a «${_cerca.text.trim()}».'),
                  for (final s in schede) _RigaGioco(s),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _RigaGioco extends StatelessWidget {
  final _Scheda s;
  const _RigaGioco(this.s);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final g = s.risultati;
    final quando = s.sessioni.isNotEmpty
        ? (s.sessioni.length == 1
            ? '${giornoLungo(s.sessioni.first.data)}, ore ${s.sessioni.first.ora}'
            : '${s.sessioni.length} appuntamenti, dal ${giornoLungo(s.sessioni.first.data).toLowerCase()}')
        : intervallo(g?.dataInizio, g?.dataFine);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaginaGioco(id: s.id, nome: s.nome, tipo: s.tipo))),
        leading: CircleAvatar(
          backgroundColor: g != null ? t.colorScheme.primaryContainer : t.colorScheme.surfaceContainerHighest,
          child: Icon(iconaGioco(s.tipo), color: g != null ? t.colorScheme.onPrimaryContainer : t.colorScheme.onSurfaceVariant),
        ),
        title: Text(s.nome, style: t.textTheme.titleMedium),
        subtitle: Text([quando, if (s.chi.isNotEmpty) s.chi].where((x) => x.isNotEmpty).join(' · ')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (g != null) Chip(label: Text(g.parziale ? 'In corso' : 'Risultati'), visualDensity: VisualDensity.compact),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}
