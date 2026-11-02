import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Immagine ferma che riempie lo spazio come BoxFit.cover, centrata, ma senza mai tagliare la sua «fascia sicura»
/// (dal 03.11.2026, pagina Info e Mappa): dove cover taglierebbe dentro la fascia, l'immagine si rimpicciolisce quanto
/// basta e le fasce vuote intorno le riempie la stessa immagine, in cover e sfocata (niente colori piatti ne' bande nere,
/// anche in tema scuro).
class ImmagineAdattata extends StatefulWidget {
  final ImageProvider immagine;
  final Size? dimensioni; // in pixel; se manca si legge dall'immagine caricata
  final Rect sicura; // fascia da non tagliare, in frazioni della larghezza e dell'altezza (0..1)
  // cose da mettere sopra l'immagine (gli stemmi della mappa): scala e origine dell'immagine nello spazio disponibile
  final List<Widget> Function(double scala, Offset origine)? sopra;
  final WidgetBuilder? seErrore;
  const ImmagineAdattata({super.key, required this.immagine, this.dimensioni, required this.sicura, this.sopra, this.seErrore});

  @override
  State<ImmagineAdattata> createState() => _ImmagineAdattataState();
}

class _ImmagineAdattataState extends State<ImmagineAdattata> {
  ImageStream? _stream;
  late final _ascolto = ImageStreamListener(
    (info, _) {
      if (mounted) setState(() => _dim = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    },
    onError: (_, __) {
      if (mounted) setState(() => _errore = true);
    },
  );
  Size? _dim;
  bool _errore = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _risolvi();
  }

  @override
  void didUpdateWidget(ImmagineAdattata vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.immagine != widget.immagine) {
      _dim = null;
      _errore = false;
      _risolvi();
    }
  }

  void _risolvi() {
    final s = widget.immagine.resolve(createLocalImageConfiguration(context));
    if (s.key == _stream?.key) return;
    _stream?.removeListener(_ascolto);
    _stream = s..addListener(_ascolto);
  }

  @override
  void dispose() {
    _stream?.removeListener(_ascolto);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errore && widget.seErrore != null) return widget.seErrore!(context);
    final dim = widget.dimensioni ?? _dim;
    if (dim == null) return const SizedBox.expand();
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight, s = widget.sicura;
      final cover = (w / dim.width) > (h / dim.height) ? w / dim.width : h / dim.height;
      final entra = [w / (s.width * dim.width), h / (s.height * dim.height)].reduce((a, b) => a < b ? a : b);
      final scala = cover < entra ? cover : entra;
      final origine = Offset((w - dim.width * scala) / 2, (h - dim.height * scala) / 2);
      return ClipRect(
        child: Stack(children: [
          // sotto: la stessa immagine in cover, sfocata, un po' piu' grande cosi' la sfocatura non schiarisce i bordi
          if (scala < cover - 0.0001)
            Positioned.fill(
              child: Transform.scale(
                scale: 1.15,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.clamp),
                  child: Image(image: widget.immagine, fit: BoxFit.cover, width: w, height: h, gaplessPlayback: true),
                ),
              ),
            ),
          Positioned(
            left: origine.dx,
            top: origine.dy,
            width: dim.width * scala,
            height: dim.height * scala,
            child: Image(image: widget.immagine, fit: BoxFit.fill, gaplessPlayback: true),
          ),
          if (widget.sopra != null) ...widget.sopra!(scala, origine),
        ]),
      );
    });
  }
}
