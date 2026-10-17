import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';
import 'sponsor.dart';

class _Canale {
  final String nome;
  final String dettaglio;
  final String url;
  final Widget icona;
  const _Canale(this.nome, this.dettaglio, this.url, this.icona);
}

class _Marchio extends StatelessWidget {
  final IconData icona;
  final Gradient sfondo;
  const _Marchio(this.icona, this.sfondo);

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(gradient: sfondo, borderRadius: BorderRadius.circular(12)),
        child: Icon(icona, color: Colors.white, size: 26),
      );
}

const _blu = LinearGradient(colors: [Color(0xFF1877F2), Color(0xFF1877F2)]);
const _instagram = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
);

// pagine social del Palio (i nomi sono i titoli pubblici delle pagine)
const _canali = [
  _Canale('Palio dei Rioni di Uggiate con Ronago', 'Facebook', 'https://www.facebook.com/profile.php?id=61589423978361&locale=it_IT',
      _Marchio(Icons.facebook, _blu)),
  _Canale('@palio.uggiateconronago', 'Instagram', 'https://www.instagram.com/palio.uggiateconronago/',
      _Marchio(Icons.photo_camera_outlined, _instagram)),
  _Canale('Comune di Uggiate con Ronago', 'Facebook', 'https://www.facebook.com/profile.php?id=61573073244162&locale=it_IT',
      _Marchio(Icons.facebook, _blu)),
];

/// Scheda Social: le pagine del Palio e, se il portale ne pubblica, gli sponsor.
class PaginaSocial extends StatefulWidget {
  const PaginaSocial({super.key});

  @override
  State<PaginaSocial> createState() => _PaginaSocialState();
}

class _PaginaSocialState extends State<PaginaSocial> {
  late Future<List<Sponsor>> _sponsor = Api.instance.sponsor().catchError((_) => <Sponsor>[]);

  Future<void> _apri(String url) async {
    final avvisi = ScaffoldMessenger.of(context);
    // con l'app Facebook o Instagram installata il link si apre li', altrimenti nel browser
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      avvisi.showSnackBar(const SnackBar(content: Text('Impossibile aprire il collegamento')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Social')),
      body: RefreshIndicator(
        onRefresh: () async {
          final f = Api.instance.sponsor().catchError((_) => <Sponsor>[]);
          setState(() => _sponsor = f);
          await f;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Segui il Palio sui social: foto, risultati e annunci delle serate.', style: t.textTheme.bodyLarge),
            ),
            for (final c in _canali)
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: c.icona,
                  title: Text(c.nome, style: t.textTheme.titleMedium),
                  subtitle: Text(c.dettaglio),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _apri(c.url),
                ),
              ),
            FutureBuilder<List<Sponsor>>(
              future: _sponsor,
              builder: (context, s) {
                final lista = s.data ?? const <Sponsor>[];
                if (lista.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Sezione('Sponsor'),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: lista.length,
                    itemBuilder: (context, i) => LogoSponsor(lista[i]),
                  ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
