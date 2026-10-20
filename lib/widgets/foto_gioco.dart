import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'icone_tratto.dart';

/// Riquadro con la foto del gioco caricata nel pannello, per le schede di Calendario e Giochi. Per gli eventi e per
/// i giochi senza foto: blu notte con l'icona in oro.
class FotoGioco extends StatelessWidget {
  final int? giocoId;
  final String tipo;
  final bool evento;
  const FotoGioco({super.key, required this.giocoId, required this.tipo, this.evento = false});

  static const larghezza = 116.0, altezza = 92.0;

  @override
  Widget build(BuildContext context) {
    final ripiego = ColoredBox(
      color: bluNotte,
      child: Center(child: evento ? const Icon(Icons.celebration, size: 36, color: oro) : IconaGioco(tipo, lato: 36, colore: oro)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: larghezza,
        height: altezza,
        child: giocoId == null
            ? ripiego
            : Image.network(
                Api.instance.url('giochi/$giocoId/foto'),
                fit: BoxFit.cover,
                cacheWidth: (larghezza * MediaQuery.devicePixelRatioOf(context)).round(),
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => ripiego,
              ),
      ),
    );
  }
}
