import 'package:flutter/material.dart';

/// Testo formattato del pannello del portale (regolamento, criteri): l'editor salva un HTML ridotto con paragrafi,
/// grassetto, corsivo, sottolineato ed elenchi; i testi scritti prima dell'editor sono testo semplice, un paragrafo
/// per riga. Qui si trasforma in widget: nessun HTML viene interpretato oltre questi tag.
class TestoRicco extends StatelessWidget {
  final String testo;
  const TestoRicco(this.testo, {super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    final blocchi = _leggi(testo);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final b in blocchi)
        Padding(
          padding: EdgeInsets.only(bottom: b.punto == null ? 10 : 4, left: b.punto == null ? 0 : 4.0 + 18.0 * (b.livello - 1)),
          child: b.punto == null
              ? Text.rich(TextSpan(children: b.pezzi), style: base)
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 26, child: Text(b.punto!, style: base)),
                  Expanded(child: Text.rich(TextSpan(children: b.pezzi), style: base)),
                ]),
        ),
    ]);
  }
}

class _Blocco {
  final String? punto; // null = paragrafo; '•' o '1.' per le voci di elenco
  final int livello;
  final List<InlineSpan> pezzi = [];
  _Blocco(this.punto, this.livello);
}

class _Elenco {
  final bool numerato;
  int n = 0;
  _Elenco(this.numerato);
}

String _entita(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

List<_Blocco> _leggi(String v) {
  final out = <_Blocco>[];
  if (v.trim().isEmpty) return out;
  if (!v.trimLeft().startsWith('<')) {
    for (final riga in v.split('\n').map((r) => r.trim()).where((r) => r.isNotEmpty)) {
      out.add(_Blocco(null, 0)..pezzi.add(TextSpan(text: riga)));
    }
    return out;
  }
  final elenchi = <_Elenco>[];
  _Blocco? corrente;
  var grassetto = 0, corsivo = 0, sotto = 0;
  final pezzo = RegExp(r'<(/?)([a-zA-Z0-9]+)[^>]*>|([^<]+)');
  for (final m in pezzo.allMatches(v)) {
    final testo = m.group(3);
    if (testo != null) {
      final t = _entita(testo.replaceAll(RegExp(r'\s+'), ' '));
      if (t.trim().isEmpty && corrente == null) continue;
      corrente ??= _Blocco(null, 0);
      if (!out.contains(corrente)) out.add(corrente);
      corrente.pezzi.add(TextSpan(
        text: corrente.pezzi.isEmpty ? t.trimLeft() : t,
        style: TextStyle(
          fontWeight: grassetto > 0 ? FontWeight.w700 : null,
          fontStyle: corsivo > 0 ? FontStyle.italic : null,
          decoration: sotto > 0 ? TextDecoration.underline : null,
        ),
      ));
      continue;
    }
    final chiude = m.group(1) == '/';
    final tag = m.group(2)!.toLowerCase();
    switch (tag) {
      case 'strong' || 'b':
        grassetto += chiude ? -1 : 1;
      case 'em' || 'i':
        corsivo += chiude ? -1 : 1;
      case 'u':
        sotto += chiude ? -1 : 1;
      case 'ul' || 'ol':
        if (chiude) {
          if (elenchi.isNotEmpty) elenchi.removeLast();
        } else {
          elenchi.add(_Elenco(tag == 'ol'));
        }
        corrente = null;
      case 'li':
        if (chiude) {
          corrente = null;
        } else {
          final e = elenchi.isEmpty ? _Elenco(false) : elenchi.last;
          e.n++;
          corrente = _Blocco(e.numerato ? '${e.n}.' : '•', elenchi.isEmpty ? 1 : elenchi.length);
          out.add(corrente);
        }
      case 'p':
        // dentro una voce di elenco il paragrafo continua la voce
        if (!chiude && (corrente == null || corrente.punto == null || corrente.pezzi.isNotEmpty)) {
          corrente = _Blocco(null, 0);
          out.add(corrente);
        } else if (chiude && corrente?.punto == null) {
          corrente = null;
        }
      case 'br':
        corrente?.pezzi.add(const TextSpan(text: '\n'));
    }
  }
  return out.where((b) => b.pezzi.isNotEmpty).toList();
}
