import 'package:flutter/material.dart';

import 'api_tesoro.dart';
import 'immagine_adattata.dart';

/// «Info»: soltanto l'immagine caricata nel pannello (dal 31.10.2026 niente titolo, testo o velature), ferma e centrata
/// (dal 03.11.2026): riempie lo spazio tagliando al massimo il 5% per lato; dove servirebbe tagliare di piu' si
/// rimpicciolisce e intorno c'e' la stessa immagine sfocata. Senza immagine, la mappa del tesoro.
class PaginaInfo extends StatelessWidget {
  final Json cfg;
  const PaginaInfo({super.key, required this.cfg});

  // pergamena e testi stanno nel 90% centrale dell'immagine
  static const _sicura = Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);

  @override
  Widget build(BuildContext context) {
    final foto = (cfg['info'] as Map?)?['foto'] as String?;
    Widget mappa(BuildContext _) => const MappaDiRiserva();
    return foto == null
        ? mappa(context)
        : ImmagineAdattata(immagine: NetworkImage(TesoroApi.instance.indirizzo(foto)), sicura: _sicura, seErrore: mappa);
  }
}

/// La mappa del tesoro (assets/mappa_tesoro.webp, 1024 x 2304): la mappa vera (da y = 384 a y = 1920) si vede
/// sempre intera.
class MappaDiRiserva extends StatelessWidget {
  const MappaDiRiserva({super.key});
  static const dimensioni = Size(1024, 2304);
  // un po' di margine sotto la mappa vera per l'etichetta del livello 1 (fascia simmetrica: l'immagine resta centrata)
  static const sicura = Rect.fromLTRB(0, 344 / 2304, 1, 1960 / 2304);

  @override
  Widget build(BuildContext context) =>
      const ImmagineAdattata(immagine: AssetImage('assets/mappa_tesoro.webp'), dimensioni: dimensioni, sicura: sicura);
}
