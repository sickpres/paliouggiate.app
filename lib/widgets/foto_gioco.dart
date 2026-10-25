import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'icone_tratto.dart';

/// Riquadro con la foto del gioco o dell'evento caricata nel pannello, per le schede di Calendario e Giochi.
/// Senza foto: blu notte con l'icona in oro.
class FotoGioco extends StatelessWidget {
  final int? giocoId;
  final String tipo;
  final bool evento;
  final int? eventoId; // evento con l'immagine: eventoId e la sua versione (cambia quando cambia l'immagine)
  final String versione;
  const FotoGioco({super.key, required this.giocoId, required this.tipo, this.evento = false, this.eventoId, this.versione = ''});

  static const larghezza = 116.0, altezza = 92.0;

  @override
  Widget build(BuildContext context) {
    final indirizzo = evento
        ? (eventoId == null ? null : '${Api.instance.url('eventi/$eventoId/foto')}?v=$versione')
        : (giocoId == null ? null : Api.instance.url('giochi/$giocoId/foto'));
    final ripiego = ColoredBox(
      color: bluNotte,
      child: Center(child: evento ? const Icon(Icons.celebration, size: 36, color: oro) : IconaGioco(tipo, lato: 36, colore: oro)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: larghezza,
        height: altezza,
        child: indirizzo == null
            ? ripiego
            : Image.network(
                indirizzo,
                fit: BoxFit.cover,
                cacheWidth: (larghezza * MediaQuery.devicePixelRatioOf(context)).round(),
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => ripiego,
              ),
      ),
    );
  }
}
