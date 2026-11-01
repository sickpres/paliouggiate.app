import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/comuni.dart';
import 'api_tesoro.dart';

/// Classifica del Tesoro, come la classifica vera: una scheda con una riga per rione (posizione, coppa per il primo,
/// stemma, punti) oppure per giocatore (avatar, stemma del rione). La posizione arriva dal portale: a parita' di punti
/// viene prima chi ha trovato il tesoro prima (dal 01.11.2026); senza, stessa posizione a parita' di punti.
class ClassificaTesoro extends StatefulWidget {
  const ClassificaTesoro({super.key});
  @override
  State<ClassificaTesoro> createState() => _ClassificaTesoroState();
}

class _ClassificaTesoroState extends State<ClassificaTesoro> {
  bool _rioni = true;

  static Future<(Json, List<Rione>)> _carica() async {
    final r = await Future.wait<Object>([TesoroApi.instance.classifica(), rioniInCache()]);
    return (r[0] as Json, r[1] as List<Rione>);
  }

  static List<int> _posizioni(List<int> punti) {
    final out = <int>[];
    for (var i = 0; i < punti.length; i++) {
      out.add(i > 0 && punti[i] == punti[i - 1] ? out[i - 1] : i + 1);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Rioni'), icon: Icon(Icons.shield_outlined)),
            ButtonSegment(value: false, label: Text('Giocatori'), icon: Icon(Icons.person_outline)),
          ],
          selected: {_rioni},
          onSelectionChanged: (s) => setState(() => _rioni = s.first),
        ),
      ),
      Expanded(
        child: DatiRemoti<(Json, List<Rione>)>(
          carica: _carica,
          costruisci: (context, d) {
            final (cl, rioni) = d;
            final righe = [for (final x in (cl[_rioni ? 'rioni' : 'giocatori'] as List)) Map<String, dynamic>.from(x as Map)];
            if (righe.isEmpty) {
              return ListView(children: const [Messaggio(icona: Icons.emoji_events_outlined, titolo: 'Ancora nessun giocatore')]);
            }
            final pos = righe.every((x) => x['posizione'] is num)
                ? [for (final x in righe) (x['posizione'] as num).toInt()]
                : _posizioni([for (final x in righe) (x['punti'] as num).toInt()]);
            final iniziata = righe.any((x) => (x['punti'] as num) > 0);
            // posizione (coppa per il primo, trattino finche' nessuno ha punti) e stemma o avatar
            Widget inizio(int i, Widget segno) => SizedBox(
                  width: 76,
                  child: Row(children: [
                    SizedBox(
                      width: 32,
                      child: !iniziata
                          ? Text('–', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))
                          : pos[i] == 1
                              ? const Icon(Icons.emoji_events, color: Color(0xFFD4A017))
                              : Text('${pos[i]}°', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    segno,
                  ]),
                );
            return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              Sezione(_rioni ? 'Classifica dei rioni' : 'Classifica dei giocatori'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var i = 0; i < righe.length; i++)
                    if (_rioni)
                      ListTile(
                        leading: inizio(i, SegnoRione(rione: rionePerNome(rioni, '${righe[i]['nome']}'), colore: '${righe[i]['colore']}')),
                        title: Text('${righe[i]['nome']}'),
                        subtitle: Text('${righe[i]['giocatori']} ${righe[i]['giocatori'] == 1 ? 'giocatore' : 'giocatori'}'
                            '${(righe[i]['tesori'] ?? 0) > 0 ? ' · ${righe[i]['tesori']} ${righe[i]['tesori'] == 1 ? 'tesoro trovato' : 'tesori trovati'}' : ''}'),
                        trailing: Text('${righe[i]['punti']}', style: t.textTheme.titleMedium),
                      )
                    else
                      ListTile(
                        leading: inizio(i, CircleAvatar(radius: 18, backgroundImage: NetworkImage(TesoroApi.instance.indirizzo(righe[i]['avatar_foto'] as String)))),
                        title: Text('${righe[i]['avatar']}'),
                        subtitle: Row(children: [
                          SegnoRione(rione: rionePerNome(rioni, '${righe[i]['rione']}'), colore: '${righe[i]['colore']}', lato: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('${righe[i]['rione']} · livello ${righe[i]['livello']}${righe[i]['tesoro'] == true ? ' · tesoro trovato' : ''}',
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                        trailing: Text('${righe[i]['punti']}', style: t.textTheme.titleMedium),
                      ),
                ]),
              ),
              const SizedBox(height: 24),
            ]);
          },
        ),
      ),
    ]);
  }
}
