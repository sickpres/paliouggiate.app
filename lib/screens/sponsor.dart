import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

class PaginaSponsor extends StatelessWidget {
  const PaginaSponsor({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor')),
      body: DatiRemoti<List<Sponsor>>(
        carica: Api.instance.sponsor,
        costruisci: (context, lista) {
          if (lista.isEmpty) {
            return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
              Messaggio(
                icona: Icons.handshake_outlined,
                titolo: 'Sponsor in arrivo',
                testo: 'Gli sponsor che sostengono il Palio saranno pubblicati qui a breve.',
              ),
            ]);
          }
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: lista.length,
            itemBuilder: (context, i) => _Logo(lista[i]),
          );
        },
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final Sponsor s;
  const _Logo(this.s);

  Future<void> _apri(BuildContext context) async {
    final uri = Uri.tryParse(s.sito);
    final avvisi = ScaffoldMessenger.of(context);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      avvisi.showSnackBar(const SnackBar(content: Text('Impossibile aprire il sito')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // i loghi sono pensati per fondo chiaro anche in tema scuro
      color: Colors.white,
      child: InkWell(
        onTap: s.sito.isEmpty ? null : () => _apri(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Expanded(
              child: Image.network(
                Api.instance.logoSponsor(s),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(child: Icon(Icons.storefront, size: 40, color: t.colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 8),
            Text(s.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall?.copyWith(color: Colors.black87)),
          ]),
        ),
      ),
    );
  }
}
