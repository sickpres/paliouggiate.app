import 'package:flutter/material.dart';

import 'comuni.dart';
import 'icone_tratto.dart';

/// Griglia di un mese (calendario e partite di pallavolo): titolo, iniziali dei giorni e solo le settimane utili.
/// Sotto ogni numero [segni] disegna i pallini degli appuntamenti del giorno.
class GrigliaMese extends StatelessWidget {
  final DateTime mese; // primo giorno del mese mostrato
  final DateTime giorno; // giorno scelto
  final ValueChanged<DateTime> onScegli;
  final Widget Function(DateTime g) segni;
  final int Function(DateTime g) quanti; // per la lettura vocale: «3 appuntamenti»
  final String unita; // 'appuntamenti' | 'partite'
  final bool Function(DateTime g) utile; // le settimane senza giorni utili non si mostrano
  const GrigliaMese({
    super.key,
    required this.mese,
    required this.giorno,
    required this.onScegli,
    required this.segni,
    required this.quanti,
    required this.unita,
    required this.utile,
  });

  static DateTime soloGiorno(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scuro = t.brightness == Brightness.dark;
    final oggi = soloGiorno(oggiApp());
    final giorniMese = DateTime(mese.year, mese.month + 1, 0).day;
    final vuoti = mese.weekday - 1; // la settimana parte dal lunedi'
    final settimane = ((vuoti + giorniMese) / 7).ceil();
    const iniziali = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

    Widget cella(int n) {
      final g = DateTime(mese.year, mese.month, n);
      final q = quanti(g);
      final scelto = stessoGiorno(g, giorno);
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
        onTap: () => onScegli(g),
        radius: 26,
        child: Semantics(
          button: true,
          selected: scelto,
          label: '${giornoLungo(g)}${q == 0 ? '' : ', $q $unita'}',
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
            SizedBox(height: 6, child: segni(g)),
          ]),
        ),
      );
    }

    var mostrate = [
      for (var s = 0; s < settimane; s++)
        if ([for (var d = 0; d < 7; d++) s * 7 + d - vuoti + 1].any((n) => n >= 1 && n <= giorniMese && utile(DateTime(mese.year, mese.month, n)))) s
    ];
    if (mostrate.isEmpty) mostrate = [for (var s = 0; s < settimane; s++) s];

    final linea = BorderSide(color: t.colorScheme.outlineVariant.withValues(alpha: 0.6), width: 0.6);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text('${mesi[mese.month - 1][0].toUpperCase()}${mesi[mese.month - 1].substring(1)} ${mese.year}',
            style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
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
      for (final s in mostrate)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(border: Border(top: linea)),
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
      Container(height: 0.6, color: linea.color),
    ]);
  }
}

/// Pallino per un appuntamento, trattino per piu' appuntamenti dello stesso tipo.
Widget segnoGiorno(Color c, int quanti) => Container(
      width: quanti > 1 ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
    );

/// Mese da cui parte la griglia: quello di oggi se ha appuntamenti, altrimenti quello del primo appuntamento.
DateTime giornoIniziale(List<DateTime> date) {
  final oggi = GrigliaMese.soloGiorno(oggiApp());
  final nelMese = date.any((d) => d.year == oggi.year && d.month == oggi.month);
  return nelMese || date.isEmpty ? oggi : GrigliaMese.soloGiorno(date.first);
}

/// Una voce del filtro scelta da un elenco in un popup (rioni della pallavolo, eta' nel calendario).
class OpzioneFiltro<T> {
  final T? valore; // null = tutti
  final String etichetta;
  final Widget? icona;
  const OpzioneFiltro(this.valore, this.etichetta, {this.icona});
}

/// Filtro per eta' (Calendario e Giochi): le categorie dei giochi del portale (pagina Giochi del pannello).
const opzioniEta = [
  OpzioneFiltro<String>(null, 'Tutti'),
  OpzioneFiltro<String>('bambini', 'Bambini'),
  OpzioneFiltro<String>('adulti', 'Adulti e ragazzi'),
  OpzioneFiltro<String>('anziani', 'Anziani'),
];

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_ETA=bambini sceglie l'eta' in Calendario e Giochi
const provaEta = String.fromEnvironment('PROVA_ETA');
String? get etaIniziale => provaEta.isEmpty ? null : provaEta;

/// Titolo della pagina con il filtro scelto dopo il pallino, come il rione nella Pallavolo: «Giochi • Bambini».
String titoloConEta(String titolo, String? eta) {
  final o = opzioniEta.where((o) => o.valore != null && o.valore == eta);
  return o.isEmpty ? titolo : '$titolo • ${o.first.etichetta}';
}

/// Un gioco della [categoria] va bene per l'[eta] scelta? Con un'eta' scelta solo i giochi di quella categoria:
/// quelli «per tutti» (e senza categoria) si vedono solo con «Tutti», cioe' senza filtro.
bool perEta(String categoria, String? eta) => eta == null || categoria == eta;

/// Popup con l'elenco delle scelte; restituisce la voce toccata (null se si chiude senza scegliere).
Future<OpzioneFiltro<T>?> scegliFiltro<T>(BuildContext context, String titolo, List<OpzioneFiltro<T>> opzioni, T? attuale) {
  return showDialog<OpzioneFiltro<T>>(
    context: context,
    builder: (context) {
      final t = Theme.of(context);
      return SimpleDialog(
        title: Text(titolo),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
        children: [
          for (final o in opzioni)
            ListTile(
              leading: o.icona,
              title: Text(o.etichetta,
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: o.valore == attuale ? FontWeight.w700 : FontWeight.w400)),
              trailing: o.valore == attuale ? Icon(Icons.check, color: t.colorScheme.primary) : null,
              selected: o.valore == attuale,
              onTap: () => Navigator.of(context).pop(o),
            ),
        ],
      );
    },
  );
}

/// Bottone «Filtra» della barra in alto, con un pallino quando un filtro e' attivo.
class BottoneFiltra extends StatelessWidget {
  final bool attivo;
  final VoidCallback onPressed;
  const BottoneFiltra({super.key, required this.attivo, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Filtra',
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: attivo,
          smallSize: 8,
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: const IconaTratto('filtro', lato: 24),
        ),
      );
}
