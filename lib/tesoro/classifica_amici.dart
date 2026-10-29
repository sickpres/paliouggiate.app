import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tema.dart';
import '../widgets/comuni.dart';
import 'api_tesoro.dart';

/// Classifica del Tesoro: rioni (somma dei loro giocatori, piu' i tesori trovati) e giocatori.
class ClassificaTesoro extends StatefulWidget {
  const ClassificaTesoro({super.key});
  @override
  State<ClassificaTesoro> createState() => _ClassificaTesoroState();
}

class _ClassificaTesoroState extends State<ClassificaTesoro> {
  bool _rioni = true;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SegmentedButton<bool>(
          segments: const [ButtonSegment(value: true, label: Text('Rioni')), ButtonSegment(value: false, label: Text('Giocatori'))],
          selected: {_rioni},
          onSelectionChanged: (s) => setState(() => _rioni = s.first),
        ),
      ),
      Expanded(
        child: DatiRemoti<Json>(
          carica: TesoroApi.instance.classifica,
          costruisci: (context, d) {
            final righe = [for (final x in (d[_rioni ? 'rioni' : 'giocatori'] as List)) Map<String, dynamic>.from(x as Map)];
            if (righe.isEmpty) return ListView(children: const [Messaggio(icona: Icons.emoji_events_outlined, titolo: 'Ancora nessun giocatore')]);
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: righe.length,
              itemBuilder: (context, i) {
                final x = righe[i];
                return Card(
                  child: ListTile(
                    leading: _rioni
                        ? CircleAvatar(backgroundColor: coloreHex('${x['colore']}'), child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))
                        : CircleAvatar(backgroundImage: NetworkImage(TesoroApi.instance.indirizzo(x['avatar_foto'] as String))),
                    title: Text(_rioni ? '${x['nome']}' : '${i + 1}. ${x['avatar']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_rioni
                        ? '${x['giocatori']} ${x['giocatori'] == 1 ? 'giocatore' : 'giocatori'}${(x['tesori'] ?? 0) > 0 ? ' · ${x['tesori']} ${x['tesori'] == 1 ? 'tesoro trovato' : 'tesori trovati'}' : ''}'
                        : '${x['rione']} · livello ${x['livello']}${x['tesoro'] == true ? ' · ha trovato il tesoro' : ''}'),
                    trailing: Text('${x['punti']}', style: const TextStyle(fontFamily: fontTitoli, fontSize: 24, fontWeight: FontWeight.w800, color: oroScuro)),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

/// «Amici del Palio»: gli sponsor; i bar dove si gioca il livello 2 hanno indirizzo e indicazioni.
class AmiciDelPalio extends StatelessWidget {
  const AmiciDelPalio({super.key});

  @override
  Widget build(BuildContext context) {
    return DatiRemoti<List<Json>>(
      carica: TesoroApi.instance.amici,
      costruisci: (context, amici) {
        if (amici.isEmpty) return ListView(children: const [Messaggio(icona: Icons.storefront_outlined, titolo: 'Gli Amici del Palio arriveranno presto')]);
        final bar = amici.where((a) => a['bar'] == true).toList(), altri = amici.where((a) => a['bar'] != true).toList();
        return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
          if (bar.isNotEmpty) const Sezione('I bar del tesoro'),
          for (final a in bar) _Amico(a),
          if (altri.isNotEmpty) const Sezione('Gli altri amici'),
          for (final a in altri) _Amico(a),
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
            if (a['bar'] == true && a['lat'] != null)
              IconButton(
                tooltip: 'Indicazioni',
                icon: const Icon(Icons.directions, color: oroScuro),
                onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${a['lat']},${a['lng']}'), mode: LaunchMode.externalApplication),
              ),
          ]),
        ),
      ),
    );
  }
}
