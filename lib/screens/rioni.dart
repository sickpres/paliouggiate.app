import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/comuni.dart';
import '../widgets/mappa.dart';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_RIONE_MAPPA=Somoca apre la pagina con quel rione scelto
const _provaRione = String.fromEnvironment('PROVA_RIONE_MAPPA');

/// Pagina «Rioni» (dal riquadro della Home): in alto la mappa disegnata dei rioni, sotto la scheda del rione scelto
/// oppure, senza rione scelto, la legenda. Il rione si sceglie sulla mappa o nella legenda.
/// titolo: dal pulsante «Partecipa» della Home la pagina si chiama «Seleziona il tuo rione».
class PaginaRioni extends StatefulWidget {
  final String titolo;
  const PaginaRioni({super.key, this.titolo = 'Rioni'});

  @override
  State<PaginaRioni> createState() => _PaginaRioniState();
}

class _PaginaRioniState extends State<PaginaRioni> {
  String? _scelto = _provaRione.isEmpty ? null : _provaRione;
  late final Future<List<Rione>> _rioni = rioniInCache();

  void _scegli(String? nome) => setState(() => _scelto = nome);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titolo)),
      body: FutureBuilder<List<Rione>>(
        future: _rioni,
        builder: (context, s) {
          final rioni = s.data ?? const <Rione>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Semantics(
                    label: 'Mappa dei rioni di Uggiate con Ronago',
                    child: MappaDisegnata(rioni: rioni, scelto: _scelto, onScegli: _scegli),
                  ),
                ),
              ),
              if (_scelto != null) SchedaRione(_scelto!, rioni),
              // la legenda solo senza rione scelto: con un rione scelto sotto la mappa c'e' la sua scheda
              if (_scelto == null && rioni.isNotEmpty) _Legenda(rioni, _scelto, _scegli),
            ],
          );
        },
      ),
    );
  }
}

/// Legenda sotto la mappa, su due colonne: stemma e nome di ogni rione; un tocco lo sceglie (o lo toglie).
class _Legenda extends StatelessWidget {
  final List<Rione> rioni;
  final String? scelto;
  final ValueChanged<String?> onScegli;
  const _Legenda(this.rioni, this.scelto, this.onScegli);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(builder: (context, c) {
          final largo = (c.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 4, children: [
            for (final r in rioni)
              SizedBox(
                width: largo,
                child: Material(
                  color: scelto == r.nome ? coloreHex(r.colore).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onScegli(scelto == r.nome ? null : r.nome),
                    child: Semantics(
                      button: true,
                      selected: scelto == r.nome,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(children: [
                          SegnoRione(rione: r, colore: r.colore, lato: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(r.nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.textTheme.titleSmall?.copyWith(fontWeight: scelto == r.nome ? FontWeight.w800 : FontWeight.w600)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}
