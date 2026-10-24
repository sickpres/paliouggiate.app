import 'package:flutter/material.dart';

import 'screens/documenti.dart';
import 'screens/gioco.dart';
import 'screens/home.dart';
import 'screens/oggi.dart';
import 'screens/rioni.dart';

/// Navigatore dell'app (MaterialApp.navigatorKey): serve per aprire una pagina da fuori dalle schermate,
/// cioe' quando si tocca una notifica push.
final navigatore = GlobalKey<NavigatorState>();

// schede del menu in basso (home.dart)
const _schede = {'home': 0, 'calendario': 1, 'classifica': 2, 'giochi': 3, 'pallavolo': 4};

/// Apre la pagina indicata nei dati di una notifica (server/notifiche.js): una scheda del menu, la pagina di un gioco
/// («gioco» con id, nome e tipo), Rioni, Documenti o Ricordi. Senza pagina, o con una sconosciuta, l'app resta com'e'.
void apriPagina(Map<String, dynamic> dati) {
  final pagina = '${dati['pagina'] ?? ''}';
  if (pagina.isEmpty) return;
  final nav = navigatore.currentState;
  if (nav == null) {
    // app appena aperta dalla notifica: si aspetta che la Home sia pronta
    WidgetsBinding.instance.addPostFrameCallback((_) => apriPagina(dati));
    return;
  }
  nav.popUntil((r) => r.isFirst);
  final scheda = _schede[pagina];
  if (scheda != null) {
    schedaHome.value = scheda;
    return;
  }
  switch (pagina) {
    case 'gioco':
      final id = int.tryParse('${dati['id']}');
      if (id == null) return;
      schedaHome.value = _schede['giochi']!;
      final nome = '${dati['nome'] ?? ''}';
      nav.push(MaterialPageRoute(builder: (_) => PaginaGioco(id: id, nome: nome.isEmpty ? 'Gioco' : nome, tipo: '${dati['tipo'] ?? ''}')));
    case 'rioni':
      nav.push(MaterialPageRoute(builder: (_) => const PaginaRioni()));
    case 'documenti':
      nav.push(MaterialPageRoute(builder: (_) => const PaginaDocumenti()));
    case 'ricordi':
      schedaHome.value = _schede['home']!;
      apriRicordi(nav.overlay!.context);
  }
}
