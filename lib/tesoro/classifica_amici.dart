import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../tema.dart';
import '../widgets/comuni.dart';
import 'api_tesoro.dart';

/// Classifica del Tesoro, come la classifica vera: una scheda con una riga per rione (posizione, coppa per il primo,
/// stemma, punti) oppure per giocatore (avatar, stemma del rione). A parita' di punti stessa posizione.
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
            final pos = _posizioni([for (final x in righe) (x['punti'] as num).toInt()]);
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

/// «Amici del Palio»: l'elenco degli sponsor, con l'indirizzo quando c'è.
class AmiciDelPalio extends StatelessWidget {
  const AmiciDelPalio({super.key});

  @override
  Widget build(BuildContext context) {
    return DatiRemoti<List<Json>>(
      carica: TesoroApi.instance.amici,
      costruisci: (context, amici) {
        if (amici.isEmpty) return ListView(children: const [Messaggio(icona: Icons.storefront_outlined, titolo: 'Gli Amici del Palio arriveranno presto')]);
        return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
          const Sezione('Gli sponsor del Palio'),
          for (final a in amici) _Amico(a),
        ]);
      },
    );
  }
}

class _Amico extends StatelessWidget {
  final Json a;
  const _Amico(this.a);

  @override
  Widget build(BuildContext context) {
    final sito = '${a['sito']}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: sito.isEmpty ? null : () => launchUrl(Uri.parse(sito), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 96,
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Image.network(TesoroApi.instance.indirizzo(a['logo'] as String), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.storefront)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['nome']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if ('${a['indirizzo']}'.isNotEmpty) Text('${a['indirizzo']}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            if ('${a['indirizzo']}'.isNotEmpty)
              IconButton(
                tooltip: 'Indicazioni',
                icon: const Icon(Icons.directions, color: oroScuro),
                onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent('${a['indirizzo']}')}'),
                    mode: LaunchMode.externalApplication),
              ),
          ]),
        ),
      ),
    );
  }
}
