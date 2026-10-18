import 'package:flutter/material.dart';

import '../promemoria.dart';
import '../widgets/icone_tratto.dart';
import 'calendario.dart';
import 'classifica.dart';
import 'documenti.dart';
import 'giochi.dart';
import 'mappa.dart';
import 'oggi.dart';
import 'pallavolo.dart';
import 'rioni.dart';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_PALLAVOLO=true / PROVA_MAPPA_GOOGLE=true
const _provaPallavolo = bool.fromEnvironment('PROVA_PALLAVOLO');
const _provaMappaGoogle = bool.fromEnvironment('PROVA_MAPPA_GOOGLE');
// --dart-define=PROVA_DOCUMENTI=true apre «Regolamento e moduli»
const _provaDocumenti = bool.fromEnvironment('PROVA_DOCUMENTI');
// --dart-define=PROVA_RIONI=true apre la pagina «Rioni»
const _provaRioni = bool.fromEnvironment('PROVA_RIONI');

const _schedaPallavolo = 4;

// scheda scelta nel menu in basso: la cambiano anche le altre pagine (es. «Calendario delle partite» del gioco)
// --dart-define=PROVA_SCHEDA=n apre direttamente la scheda n (schermate di prova)
final schedaHome = ValueNotifier<int>(_provaPallavolo ? _schedaPallavolo : const int.fromEnvironment('PROVA_SCHEDA'));

/// Porta alla scheda Pallavolo, chiudendo le pagine aperte sopra il menu.
void apriPallavolo(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  schedaHome.value = _schedaPallavolo;
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const _pagine = [PaginaOggi(), PaginaCalendario(), PaginaClassifica(), PaginaGiochi(), PaginaPallavolo()];

  // a ogni ritorno nell'app si riscarica il piano dei promemoria
  late final AppLifecycleListener _ciclo;

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: Promemoria.aggiorna);
    if (_provaMappaGoogle) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaMappa())));
    }
    if (_provaRioni) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaRioni())));
    }
    if (_provaDocumenti) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaDocumenti())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: schedaHome,
      builder: (context, scheda, _) => Scaffold(
        body: IndexedStack(index: scheda, children: _pagine),
        bottomNavigationBar: MenuInBasso(
          scelta: scheda,
          onScegli: (i) => schedaHome.value = i,
          voci: const [
            VoceMenu('home', 'Home'),
            VoceMenu('calendario_menu', 'Calendario'),
            VoceMenu('classifica_menu', 'Classifica'),
            VoceMenu('giochi_menu', 'Giochi'),
            VoceMenu('gioco_pallavolo', 'Pallavolo'),
          ],
        ),
      ),
    );
  }
}
