import 'package:flutter/material.dart';

import 'api_tesoro.dart';

/// «Info»: soltanto l'immagine caricata nel pannello (dal 31.10.2026 niente titolo, testo o velature), intera e larga
/// quanto lo schermo; se e' piu' alta si scorre. Senza immagine, la mappa del tesoro.
class PaginaInfo extends StatelessWidget {
  final Json cfg;
  const PaginaInfo({super.key, required this.cfg});

  @override
  Widget build(BuildContext context) {
    final foto = (cfg['info'] as Map?)?['foto'] as String?;
    const mappa = Image(image: AssetImage('assets/mappa_tesoro.webp'), width: double.infinity, fit: BoxFit.fitWidth);
    return SingleChildScrollView(
      child: foto == null
          ? mappa
          : Image.network(TesoroApi.instance.indirizzo(foto), width: double.infinity, fit: BoxFit.fitWidth, errorBuilder: (_, __, ___) => mappa),
    );
  }
}
