import 'package:flutter/material.dart';

import '../widgets/comuni.dart';
import '../widgets/icone_tratto.dart';
import '../widgets/mappa.dart';
import 'mappa.dart';

/// Pagina «Rioni» (dal riquadro della Home): la mappa dei rioni come sul portale, con la scheda del rione toccato,
/// e il bottone per la mappa vera (Google Maps) con i confini.
class PaginaRioni extends StatelessWidget {
  const PaginaRioni({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rioni')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Sezione(
            'Gli otto rioni',
            coda: FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaMappa())),
              icon: const IconaTratto('mappa', lato: 18),
              label: const Text('Mappa'),
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
          const MappaRioni(),
        ],
      ),
    );
  }
}
