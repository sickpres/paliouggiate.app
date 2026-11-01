import 'package:flutter/material.dart';

import 'api_tesoro.dart';

/// «Info»: soltanto l'immagine caricata nel pannello (dal 31.10.2026 niente titolo, testo o velature), intera e
/// ferma come la mappa (dal 01.11.2026 non scorre piu'): grande quanto lo schermo permette, senza ritagli.
/// Senza immagine, la mappa del tesoro.
class PaginaInfo extends StatelessWidget {
  final Json cfg;
  const PaginaInfo({super.key, required this.cfg});

  @override
  Widget build(BuildContext context) {
    final foto = (cfg['info'] as Map?)?['foto'] as String?;
    const mappa = Image(image: AssetImage('assets/mappa_tesoro.webp'), fit: BoxFit.cover);
    return SizedBox.expand(
      child: foto == null
          ? mappa
          : Image.network(TesoroApi.instance.indirizzo(foto), fit: BoxFit.contain, errorBuilder: (_, __, ___) => mappa),
    );
  }
}
