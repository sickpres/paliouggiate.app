import 'package:flutter/material.dart';

import '../tema.dart';
import 'api_tesoro.dart';

/// «Info»: come si gioca, con titolo e testo scelti nel pannello davanti all'immagine di sfondo (se non c'e', la mappa
/// del tesoro), su un velo scuro. Ogni riga va a capo; una riga corta senza punto finale e' un titoletto, una che
/// comincia con «•» un punto dell'elenco.
class PaginaInfo extends StatelessWidget {
  final Json cfg;
  const PaginaInfo({super.key, required this.cfg});

  @override
  Widget build(BuildContext context) {
    final info = Map<String, dynamic>.from((cfg['info'] as Map?) ?? const {});
    final foto = info['foto'] as String?;
    final righe = '${info['testo'] ?? ''}'.split('\n');
    return Stack(fit: StackFit.expand, children: [
      foto == null
          ? Image.asset('assets/mappa_tesoro.webp', fit: BoxFit.cover)
          : Image.network(TesoroApi.instance.indirizzo(foto), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset('assets/mappa_tesoro.webp', fit: BoxFit.cover)),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99062246), Color(0xE6062246)],
          ),
        ),
      ),
      // fisso, senza scorrere: se il testo e' lungo si rimpicciolisce quanto serve per stare nello schermo
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        child: LayoutBuilder(
          builder: (context, c) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: c.maxWidth,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${info['titolo'] ?? ''}',
                    style: const TextStyle(fontFamily: fontTitoli, fontSize: 34, height: 1.1, fontWeight: FontWeight.w800, color: oro,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
                const SizedBox(height: 14),
                for (final r in righe) _riga(r.trimRight()),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _riga(String r) {
    const bianco = TextStyle(color: Colors.white, fontSize: 17, height: 1.4, shadows: [Shadow(color: Colors.black54, blurRadius: 6)]);
    if (r.trim().isEmpty) return const SizedBox(height: 12);
    if (r.startsWith('•')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 9, right: 10), child: Icon(Icons.circle, size: 8, color: oro)),
          Expanded(child: Text(r.substring(1).trim(), style: bianco)),
        ]),
      );
    }
    final titoletto = r.length <= 40 && !RegExp(r'[.!?:;,…]$').hasMatch(r);
    if (titoletto) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(r, style: const TextStyle(fontFamily: fontTitoli, fontSize: 22, fontWeight: FontWeight.w800, color: oro)),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(r, style: bianco));
  }
}
