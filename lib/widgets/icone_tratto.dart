import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'icone_tratto_dati.dart';

/// Icona a tratto 24 x 24 (portale e Lucide), del colore e della misura dell'IconTheme se non indicati.
class IconaTratto extends StatelessWidget {
  final String nome;
  final double? lato;
  final Color? colore;
  final double spessore;
  const IconaTratto(this.nome, {super.key, this.lato, this.colore, this.spessore = 1.75});

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final l = lato ?? tema.size ?? 24;
    final traccia = tracceIcone[nome];
    if (traccia == null) return SizedBox(width: l, height: l);
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="$spessore" '
      'stroke-linecap="round" stroke-linejoin="round">$traccia</svg>',
      width: l,
      height: l,
      colorFilter: ColorFilter.mode(colore ?? tema.color ?? Colors.black, BlendMode.srcIn),
    );
  }
}

/// Icona di un gioco: la stessa del portale (menu e pagine dei giochi del pannello).
class IconaGioco extends StatelessWidget {
  final String tipo;
  final double? lato;
  final Color? colore;
  const IconaGioco(this.tipo, {super.key, this.lato, this.colore});

  @override
  Widget build(BuildContext context) => tracceIcone.containsKey('gioco_$tipo')
      ? IconaTratto('gioco_$tipo', lato: lato, colore: colore)
      : IconaTratto('giochi_menu', lato: lato, colore: colore);
}

class VoceMenu {
  final String icona;
  final String etichetta;
  const VoceMenu(this.icona, this.etichetta);
}

/// Menu in basso (principale e pagina del gioco), con le misure del menu dell'app Sisal: barra alta 59,5 pt piu'
/// l'area di sicurezza, icone a tratto da 21,5 pt, etichette da 12,2 pt a 4,5 pt dall'icona, nessuna pillola. La voce
/// scelta ha il tratto piu' spesso e il testo in grassetto. I colori vengono dal tema (navigationBarTheme).
class MenuInBasso extends StatelessWidget {
  final int scelta;
  final ValueChanged<int> onScegli;
  final List<VoceMenu> voci;
  const MenuInBasso({super.key, required this.scelta, required this.onScegli, required this.voci});

  static const altezza = 59.5;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final nb = t.navigationBarTheme;
    const scelto = {WidgetState.selected};
    const spento = <WidgetState>{};
    // stesse misure per tutti i menu (principale e pagina del gioco)
    TextStyle testo(Set<WidgetState> st) => (nb.labelTextStyle?.resolve(st) ?? const TextStyle()).copyWith(fontSize: 12.2, height: 1.15);
    Color colore(Set<WidgetState> st) => nb.iconTheme?.resolve(st)?.color ?? t.colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: nb.backgroundColor,
        border: Border(top: BorderSide(color: t.brightness == Brightness.dark ? Colors.white10 : t.colorScheme.outlineVariant, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: altezza,
          child: Row(children: [
            for (var i = 0; i < voci.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == scelta,
                  label: voci[i].etichetta,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => onScegli(i),
                    highlightShape: BoxShape.rectangle,
                    containedInkWell: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.6),
                      child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                        IconaTratto(voci[i].icona, lato: 21.5, spessore: i == scelta ? 2.25 : 1.75, colore: colore(i == scelta ? scelto : spento)),
                        const SizedBox(height: 4.5),
                        Text(voci[i].etichetta, maxLines: 1, overflow: TextOverflow.visible, softWrap: false,
                            style: testo(i == scelta ? scelto : spento)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
